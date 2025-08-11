//
//  CanvasView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State Bindings
    @Binding var size: CGSize
    @Binding var magnification: CGFloat
    @Binding var nodes: [BaseNode]
    @Binding var selection: Set<UUID>
    @Binding var tool: CanvasTool?
    
    @Binding var layers: [CanvasLayer]
    @Binding var activeLayerId: UUID?

    // MARK: - Callbacks & Configuration
    let environment: CanvasEnvironmentValues
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider

    var onMouseMoved: ((CGPoint?) -> Void)?
    
    let registeredDraggedTypes: [NSPasteboard.PasteboardType]

    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?
    
    var onModelDidChange: (() -> Void)?

    init(
        size: Binding<CGSize>,
        magnification: Binding<CGFloat>,
        nodes: Binding<[BaseNode]>,
        selection: Binding<Set<UUID>>,
        tool: Binding<CanvasTool?> = .constant(nil),
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        onMouseMoved: ((CGPoint?) -> Void)? = nil,
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil,
        onModelDidChange: (() -> Void)? = {}
    ) {
        self._size = size
        self._magnification = magnification
        self._nodes = nodes
        self._selection = selection
        self._tool = tool
        self._layers = layers
         self._activeLayerId = activeLayerId
        self.environment = environment
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.onMouseMoved = onMouseMoved
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
        self.onModelDidChange = onModelDidChange
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        private var magnificationBinding: Binding<CGFloat>
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[BaseNode]>
        private var magnificationObservation: NSKeyValueObservation?
        private var boundsChangeObserver: Any?

        init(
            magnification: Binding<CGFloat>,
            nodes: Binding<[BaseNode]>,
            selection: Binding<Set<UUID>>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.magnificationBinding = magnification
            self.nodesBinding = nodes
            self.selectionBinding = selection
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions, inputProcessors: inputProcessors, snapProvider: snapProvider)
            super.init()
            setupControllerCallbacks()
        }

        private func setupControllerCallbacks() {
            canvasController.onSelectionChanged = { [weak self] newSelectionIDs in
                DispatchQueue.main.async { self?.selectionBinding.wrappedValue = newSelectionIDs }
            }
            canvasController.onNodesChanged = { [weak self] newNodes in
                DispatchQueue.main.async { self?.nodesBinding.wrappedValue = newNodes }
            }
        }
        
        func observeScrollView(_ scrollView: NSScrollView) {
            magnificationObservation = scrollView.observe(\.magnification, options: .new) { [weak self] _, change in
                guard let self = self, let newValue = change.newValue else { return }
                DispatchQueue.main.async {
                    if !self.magnificationBinding.wrappedValue.isApproximatelyEqual(to: newValue) {
                        self.magnificationBinding.wrappedValue = newValue
                    }
                }
            }
    
            guard let clipView = scrollView.contentView as? NSClipView else { return }
            
            clipView.postsBoundsChangedNotifications = true
            
            self.boundsChangeObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.canvasController.redraw()
            }
        }
        
        deinit {
            magnificationObservation?.invalidate()
 
            if let observer = boundsChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            magnification: $magnification,
            nodes: $nodes,
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions,
            inputProcessors: self.inputProcessors,
            snapProvider: self.snapProvider,
        )
        coordinator.canvasController.onMouseMoved = self.onMouseMoved
        coordinator.canvasController.onMouseMoved = self.onMouseMoved
        coordinator.canvasController.onPasteboardDropped = self.onPasteboardDropped
        coordinator.canvasController.onModelDidChange = self.onModelDidChange
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController, registeredDraggedTypes: self.registeredDraggedTypes)
        let scrollView = CenteringNSScrollView()
        
        coordinator.canvasController.onNeedsRedraw = { [weak canvasHostView] in
            canvasHostView?.performLayerUpdate()
        }

        scrollView.documentView = canvasHostView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        
        coordinator.observeScrollView(scrollView)
        
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        
        controller.sync(
            nodes: self.nodes,
            selection: self.selection,
            tool: self.tool,
            magnification: self.magnification,
            environment: self.environment,
            layers: self.layers,
                   activeLayerId: self.activeLayerId
        )
        
        if let hostView = scrollView.documentView, hostView.frame.size != self.size {
            hostView.frame.size = self.size
        }
        
        if !scrollView.magnification.isApproximatelyEqual(to: self.magnification) {
            scrollView.magnification = self.magnification
        }
        
        scrollView.documentView?.needsDisplay = true
    }
}

extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
