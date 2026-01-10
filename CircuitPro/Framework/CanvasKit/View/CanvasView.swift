import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State

    @Binding var viewport: CanvasViewport
    @Binding var tool: CanvasTool?

    @Binding var layers: [any CanvasLayer]

    @Binding var activeLayerId: UUID?

    private var itemsBinding: Binding<[any CanvasItem]>?
    private var selectedIDsBinding: Binding<Set<UUID>>?
    private var connectionEngine: (any ConnectionEngine)?

    // MARK: - Callbacks & Configuration
    let environment: CanvasEnvironmentValues
    let renderLayers: [any CKRenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider

    let registeredDraggedTypes: [NSPasteboard.PasteboardType]
    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?
    var onCanvasChange: ((CanvasChangeContext) -> Void)?

    init(
        viewport: Binding<CanvasViewport>,
        tool: Binding<CanvasTool?> = .constant(nil),
        items: Binding<[any CanvasItem]>,
        selectedIDs: Binding<Set<UUID>>,
        layers: Binding<[any CanvasLayer]> = .constant([] as [any CanvasLayer]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        connectionEngine: (any ConnectionEngine)? = nil,
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any CKRenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil
    ) {
        self._viewport = viewport
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = items
        self.selectedIDsBinding = selectedIDs
        self.connectionEngine = connectionEngine
        self.environment = environment
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        let canvasController: CanvasController
        fileprivate var updateSelectedIDs: ((Set<UUID>) -> Void)?

        private var viewportBinding: Binding<CanvasViewport>

        private var magnificationObservation: NSKeyValueObservation?
        private var boundsChangeObserver: Any?

        init(
            viewport: Binding<CanvasViewport>,
            renderLayers: [any CKRenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.viewportBinding = viewport
            self.canvasController = CanvasController(
                renderLayers: renderLayers,
                interactions: interactions,
                inputProcessors: inputProcessors,
                snapProvider: snapProvider
            )
            super.init()
        }

        func observeScrollView(_ scrollView: NSScrollView) {
            magnificationObservation = scrollView.observe(\.magnification, options: .new) { [weak self] _, change in
                guard let self = self, let newValue = change.newValue else { return }
                DispatchQueue.main.async {
                    if !self.viewportBinding.wrappedValue.magnification.isApproximatelyEqual(to: newValue) {
                        self.viewportBinding.wrappedValue.magnification = newValue
                    }
                    self.canvasController.viewportDidMagnify(to: newValue)
                }
            }

            guard let clipView = scrollView.contentView as? NSClipView else { return }

            clipView.postsBoundsChangedNotifications = true

            boundsChangeObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.viewportBinding.wrappedValue.visibleRect = clipView.bounds
                    self.canvasController.viewportDidScroll(to: clipView.bounds)
                }
            }
        }

        deinit {
            magnificationObservation?.invalidate()
            if let observer = boundsChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    @MainActor
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            viewport: $viewport,
            renderLayers: self.renderLayers,
            interactions: self.interactions,
            inputProcessors: self.inputProcessors,
            snapProvider: self.snapProvider
        )
        coordinator.canvasController.onPasteboardDropped = self.onPasteboardDropped
        coordinator.canvasController.onCanvasChange = self.onCanvasChange
        return coordinator
    }

    // MARK: - NSViewRepresentable Lifecycle

    @MainActor
    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let canvasHostView = CanvasHostView(controller: coordinator.canvasController, registeredDraggedTypes: self.registeredDraggedTypes)
        let scrollView = CenteringNSScrollView()

        coordinator.canvasController.view = canvasHostView

        scrollView.documentView = canvasHostView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0

        coordinator.observeScrollView(scrollView)

        return scrollView
    }

    @MainActor
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        controller.onCanvasChange = self.onCanvasChange

        let items = itemsBinding?.wrappedValue ?? []

        var environment = self.environment
            .withConnectionEngine(connectionEngine)
        if let itemsBinding {
            environment = environment.withItems(itemsBinding)
        }

        let selectedIDs = selectedIDsBinding?.wrappedValue ?? []
        if let selectedIDsBinding {
            context.coordinator.updateSelectedIDs = { newSelection in
                if selectedIDsBinding.wrappedValue != newSelection {
                    selectedIDsBinding.wrappedValue = newSelection
                }
            }
            controller.onSelectionChange = context.coordinator.updateSelectedIDs
        } else {
            controller.onSelectionChange = nil
        }

        controller.sync(
            tool: self.tool,
            magnification: self.viewport.magnification,
            environment: environment,
            layers: self.layers,
            activeLayerId: self.activeLayerId,
            selectedItemIDs: selectedIDs,
            items: items
        )

        if let hostView = scrollView.documentView, hostView.frame.size != self.viewport.size {
            hostView.frame.size = self.viewport.size
        }

        if !scrollView.magnification.isApproximatelyEqual(to: self.viewport.magnification) {
            scrollView.magnification = self.viewport.magnification
        }

        if let clipView = scrollView.contentView as? NSClipView {
            if self.viewport.visibleRect != CanvasViewport.autoCenter && clipView.bounds.origin != self.viewport.visibleRect.origin {
                clipView.bounds.origin = self.viewport.visibleRect.origin
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
