import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: - SwiftUI State

    @Binding var viewport: CanvasViewport
    @Bindable var scene: CanvasScene
    @Binding var tool: CanvasTool?

    @Binding var layers: [CanvasLayer]

    @Binding var activeLayerId: UUID?

    private var itemsBinding: Binding<[any CanvasItem]>?
    private var selectedIDsBinding: Binding<Set<UUID>>?
    private var connectionEngine: (any ConnectionEngine)?

    // MARK: - Callbacks & Configuration
    let environment: CanvasEnvironmentValues
    let renderLayers: [any RenderLayer]
    let interactions: [any CanvasInteraction]
    let inputProcessors: [any InputProcessor]
    let snapProvider: any SnapProvider

    let registeredDraggedTypes: [NSPasteboard.PasteboardType]
    let onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)?
    var onCanvasChange: ((CanvasChangeContext) -> Void)?

    init(
        viewport: Binding<CanvasViewport>,
        store: CanvasStore,
        tool: Binding<CanvasTool?> = .constant(nil),
        graph: CanvasGraph,
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        connections: (any ConnectionEngine)? = nil,
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil
    ) {
        self._viewport = viewport
        self.scene = CanvasScene(graph: graph, store: store)
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = nil
        self.selectedIDsBinding = nil
        self.connectionEngine = connections
        self.environment = environment
            .withCanvasStore(scene.store)
            .withConnectionEngine(connections)
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    init(
        viewport: Binding<CanvasViewport>,
        store: CanvasStore,
        tool: Binding<CanvasTool?> = .constant(nil),
        items: Binding<[any CanvasItem]>,
        selectedIDs: Binding<Set<UUID>>,
        graph: CanvasGraph,
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        connections: (any ConnectionEngine)? = nil,
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil
    ) {
        self._viewport = viewport
        self.scene = CanvasScene(graph: graph, store: store)
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = items
        self.selectedIDsBinding = selectedIDs
        self.connectionEngine = connections
        self.environment = environment
            .withCanvasStore(scene.store)
            .withConnectionEngine(connections)
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    init(
        viewport: Binding<CanvasViewport>,
        scene: CanvasScene,
        tool: Binding<CanvasTool?> = .constant(nil),
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        connections: (any ConnectionEngine)? = nil,
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil
    ) {
        self._viewport = viewport
        self.scene = scene
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = nil
        self.selectedIDsBinding = nil
        self.connectionEngine = connections
        self.environment = environment
            .withCanvasStore(scene.store)
            .withConnectionEngine(connections)
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    init(
        viewport: Binding<CanvasViewport>,
        scene: CanvasScene,
        tool: Binding<CanvasTool?> = .constant(nil),
        items: Binding<[any CanvasItem]>,
        selectedIDs: Binding<Set<UUID>>,
        layers: Binding<[CanvasLayer]> = .constant([]),
        activeLayerId: Binding<UUID?> = .constant(nil),
        connections: (any ConnectionEngine)? = nil,
        environment: CanvasEnvironmentValues = .init(),
        renderLayers: [any RenderLayer],
        interactions: [any CanvasInteraction],
        inputProcessors: [any InputProcessor] = [],
        snapProvider: any SnapProvider = NoOpSnapProvider(),
        registeredDraggedTypes: [NSPasteboard.PasteboardType] = [],
        onPasteboardDropped: ((NSPasteboard, CGPoint) -> Bool)? = nil
    ) {
        self._viewport = viewport
        self.scene = scene
        self._tool = tool
        self._layers = layers
        self._activeLayerId = activeLayerId
        self.itemsBinding = items
        self.selectedIDsBinding = selectedIDs
        self.connectionEngine = connections
        self.environment = environment
            .withCanvasStore(scene.store)
            .withConnectionEngine(connections)
        self.renderLayers = renderLayers
        self.interactions = interactions
        self.inputProcessors = inputProcessors
        self.snapProvider = snapProvider
        self.registeredDraggedTypes = registeredDraggedTypes
        self.onPasteboardDropped = onPasteboardDropped
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let canvasController: CanvasController
        let itemGraphSync = CanvasItemGraphSync()

        private var viewportBinding: Binding<CanvasViewport>

        private var magnificationObservation: NSKeyValueObservation?
        private var boundsChangeObserver: Any?

        init(
            viewport: Binding<CanvasViewport>,
            renderLayers: [any RenderLayer],
            interactions: [any CanvasInteraction],
            inputProcessors: [any InputProcessor],
            snapProvider: any SnapProvider
        ) {
            self.viewportBinding = viewport
            self.canvasController = CanvasController(renderLayers: renderLayers, interactions: interactions, inputProcessors: inputProcessors, snapProvider: snapProvider)
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

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let controller = context.coordinator.canvasController
        controller.onCanvasChange = self.onCanvasChange
        _ = scene.store.revision

        if let itemsBinding = itemsBinding {
            let items = itemsBinding.wrappedValue
            context.coordinator.itemGraphSync.sync(items: items, graph: scene.graph)

            if let consumer = connectionEngine as? ConnectionPointConsumer {
                var points: [any ConnectionPoint] = []
                points.reserveCapacity(items.count)
                for item in items {
                    if let provider = item as? ConnectionPointProvider {
                        points.append(contentsOf: provider.connectionPoints)
                    }
                }
                consumer.updateConnectionPoints(points)
            }
        }

        if let selectedIDsBinding = selectedIDsBinding {
            let selectedIDs = selectedIDsBinding.wrappedValue
            let desiredSelection = Set(selectedIDs.map { GraphElementID.node(NodeID($0)) })
            if scene.graph.selection != desiredSelection {
                scene.graph.selection = desiredSelection
            }
            if scene.store.selection != selectedIDs {
                scene.store.selection = selectedIDs
            }
        }

        controller.sync(
            tool: self.tool,
            magnification: self.viewport.magnification,
            environment: self.environment,
            layers: self.layers,
            activeLayerId: self.activeLayerId,
            graph: scene.graph
        )

        if let selectedIDsBinding = selectedIDsBinding {
            let graphSelectionIDs = Set(scene.graph.selection.compactMap { $0.nodeID?.rawValue })
            if selectedIDsBinding.wrappedValue != graphSelectionIDs {
                selectedIDsBinding.wrappedValue = graphSelectionIDs
            }
            if scene.store.selection != graphSelectionIDs {
                scene.store.selection = graphSelectionIDs
            }
        }

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
