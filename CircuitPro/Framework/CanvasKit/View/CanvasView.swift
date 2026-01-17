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

    // MARK: - Callbacks & Configuration
    var environment: CanvasEnvironmentValues
    let renderViews: [any CKView]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider

    let registeredDraggedTypes: [NSPasteboard.PasteboardType]
    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?

    init(
        tool: Binding<CanvasTool?> = .constant(nil),
        items: Binding<[any CanvasItem]>,
        selectedIDs: Binding<Set<UUID>>,
        layers: Binding<[any CanvasLayer]> = .constant([] as [any CanvasLayer]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        environment: CanvasEnvironmentValues = .init(),
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil,
        @CKViewBuilder content: @escaping () -> CKGroup
    ) {
        self._viewport = .constant(CanvasViewport(size: .zero, magnification: 1.0, visibleRect: CanvasViewport.autoCenter))
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = items
        self.selectedIDsBinding = selectedIDs
        var env = environment
        self.environment = env
        self.renderViews = [content()]
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
            renderViews: [any CKView],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.viewportBinding = viewport
            self.canvasController = CanvasController(
                renderViews: renderViews,
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

            let clipView: NSClipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true

            boundsChangeObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let newBounds = clipView.bounds
                    if self.viewportBinding.wrappedValue.visibleRect != newBounds {
                        self.viewportBinding.wrappedValue.visibleRect = newBounds
                        self.canvasController.viewportDidScroll(to: newBounds)
                    }
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
            renderViews: self.renderViews,
            inputProcessors: self.inputProcessors,
            snapProvider: self.snapProvider
        )
        coordinator.canvasController.onPasteboardDropped = self.onPasteboardDropped
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

        let items = itemsBinding?.wrappedValue ?? []

        var environment = self.environment

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

        environment = environment
            .withHoverHandler { [weak controller] id, isInside in
                guard let controller else { return }
                if isInside {
                    controller.setInteractionHighlight(itemIDs: [id], needsDisplay: false)
                } else if controller.highlightedItemIDs == [id] {
                    controller.setInteractionHighlight(itemIDs: [], needsDisplay: false)
                }
            }
            .withTapHandler { [weak controller] id in
                controller?.updateSelection([id])
            }
            .withDragHandler { _ , _ in }

        controller.sync(
            tool: self.tool,
            magnification: self.viewport.magnification,
            environment: environment,
            layers: self.layers,
            activeLayerId: self.activeLayerId,
            selectedItemIDs: selectedIDs,
            items: items,
            itemsBinding: itemsBinding
        )

        if let hostView = scrollView.documentView, hostView.frame.size != self.viewport.size {
            hostView.frame.size = self.viewport.size
        }

        if !scrollView.magnification.isApproximatelyEqual(to: self.viewport.magnification) {
            scrollView.magnification = self.viewport.magnification
        }

        do {
            let clipView: NSClipView = scrollView.contentView
            if self.viewport.visibleRect != CanvasViewport.autoCenter && clipView.bounds.origin != self.viewport.visibleRect.origin {
                clipView.bounds.origin = self.viewport.visibleRect.origin
            }
        }

    }
}


extension CGFloat {
    func isApproximatelyEqual(to other: CGFloat, tolerance: CGFloat = 1e-9) -> Bool {
        return abs(self - other) <= tolerance
    }
}

extension CanvasView {
    func viewport(_ binding: Binding<CanvasViewport>) -> CanvasView {
        var copy = self
        copy._viewport = binding
        return copy
    }

    func canvasTool(_ binding: Binding<CanvasTool?>) -> CanvasView {
        var copy = self
        copy._tool = binding
        return copy
    }

    func canvasEnvironment(_ value: CanvasEnvironmentValues) -> CanvasView {
        var copy = self
        var env = value
        copy.environment = env
        return copy
    }
}
