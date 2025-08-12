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
    // Consolidated into a single binding!
    @Binding var viewport: CanvasViewport
    
    // Model-related bindings remain separate
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
    
    let registeredDraggedTypes: [NSPasteboard.PasteboardType]
    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?
    var onModelDidChange: (() -> Void)?
    var onCanvasChange: ((CanvasChangeContext) -> Void)?

    init(
        viewport: Binding<CanvasViewport>,
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
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil,
        onModelDidChange: (() -> Void)? = {}
    ) {
        self._viewport = viewport
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
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
        self.onModelDidChange = onModelDidChange
    }

    // MARK: - Coordinator
    
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        
        // The coordinator now holds a binding to the entire viewport struct.
        private var viewportBinding: Binding<CanvasViewport>
        
        private var selectionBinding: Binding<Set<UUID>>
        private var nodesBinding: Binding<[BaseNode]>
        private var magnificationObservation: NSKeyValueObservation?
        private var boundsChangeObserver: Any?

        init(
            viewport: Binding<CanvasViewport>,
            nodes: Binding<[BaseNode]>,
            selection: Binding<Set<UUID>>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.viewportBinding = viewport
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
                    if !self.viewportBinding.wrappedValue.magnification.isApproximatelyEqual(to: newValue) {
                        // Update the magnification on the binding
                        self.viewportBinding.wrappedValue.magnification = newValue
                    }
                }
            }
    
            guard let clipView = scrollView.contentView as? NSClipView else { return }
            
            clipView.postsBoundsChangedNotifications = true
            
            // This observer now updates the visibleRect on the binding.
            self.boundsChangeObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    // Update the visibleRect on the binding
                    self.viewportBinding.wrappedValue.visibleRect = clipView.bounds
                }
                self.canvasController.redraw()
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
            viewport: $viewport, // Pass the single binding
            nodes: $nodes,
            selection: $selection,
            renderLayers: self.renderLayers,
            interactions: self.interactions,
            inputProcessors: self.inputProcessors,
            snapProvider: self.snapProvider
        )
        // Wire up other callbacks...
        coordinator.canvasController.onPasteboardDropped = self.onPasteboardDropped
        coordinator.canvasController.onModelDidChange = self.onModelDidChange
        coordinator.canvasController.onCanvasChange = self.onCanvasChange
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    func makeNSView(context: Context) -> NSScrollView {
        // ... (makeNSView is mostly the same, creating the host view and scroll view) ...
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
        controller.onCanvasChange = self.onCanvasChange
        
        controller.sync(
            nodes: self.nodes,
            selection: self.selection,
            tool: self.tool,
            magnification: self.viewport.magnification, // Read from viewport
            environment: self.environment,
            layers: self.layers,
            activeLayerId: self.activeLayerId
        )
        
        // Sync state from SwiftUI (@Binding) to the AppKit view
        if let hostView = scrollView.documentView, hostView.frame.size != self.viewport.size {
            hostView.frame.size = self.viewport.size
        }
        
        if !scrollView.magnification.isApproximatelyEqual(to: self.viewport.magnification) {
            scrollView.magnification = self.viewport.magnification
        }
        
        // This makes programmatic scrolling possible!
        if let clipView = scrollView.contentView as? NSClipView {
            
            // We only apply the binding's value to the view IF it's not our
            // special "autoCenter" command. This allows CenteringNSScrollView's
            // initial layout to "win" the first race.
            if self.viewport.visibleRect != CanvasViewport.autoCenter && clipView.bounds != self.viewport.visibleRect {
                // Once the binding has a real rect, it becomes the source of truth.
                clipView.bounds = self.viewport.visibleRect
            }
        }
        
        scrollView.documentView?.needsDisplay = true
    }
}

extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}
