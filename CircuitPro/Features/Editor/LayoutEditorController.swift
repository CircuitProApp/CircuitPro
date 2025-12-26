import SwiftUI
import Observation

/// The high-level controller for the layout editor.
///
/// This class is the single source of truth for the layout canvas's view state. It observes the
/// core `ProjectManager` data and is responsible for building the renderable scene graph
/// of footprints and traces. It also manages layout-specific UI state like the active layer.
@MainActor
@Observable
final class LayoutEditorController: EditorController {

    // MARK: - EditorController Conformance

    /// The final, renderable scene graph for the layout canvas.
    let canvasStore = CanvasStore()

    var nodes: [BaseNode] { canvasStore.nodes }

    let graph = Graph()
    private var suppressGraphSelectionSync = false
    private var suppressPrimitiveRemoval = false
    private var primitiveCache: [NodeID: AnyCanvasPrimitive] = [:]
    private var activeDesignID: UUID?
    private var graphNodeProxyIDs: Set<NodeID> = []

    // MARK: - Layout-Specific State

    /// The ID of the currently active layer for editing (e.g., for routing traces).
    var activeLayerId: UUID? = nil

    /// The list of layers relevant to the current design's layout, sorted for rendering.
    var canvasLayers: [CanvasLayer] = []

    /// The graph model for managing traces, vias, and other layout geometry. Owned by this controller.
    private let traceGraph: TraceGraph

    var selectedTool: CanvasTool = CursorTool()

    // MARK: - Dependencies

    @ObservationIgnored private let projectManager: ProjectManager

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.traceGraph = TraceGraph()
        self.canvasStore.onNodesChanged = { [weak self] nodes in
            self?.syncGraphNodeProxies(from: nodes)
        }
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }

        // Start the automatic observation loop upon initialization.
        startTrackingModelChanges()

        Task {
            await self.rebuildNodes()
        }
    }

    private func startTrackingModelChanges() {
        withObservationTracking {
            // Rebuild layout nodes if the design or its components change.
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            // Also watch for changes from the sync manager for pending ECOs.
            _ = projectManager.syncManager.pendingChanges
            // Track nested data that affects footprint text rendering.
            for comp in projectManager.componentInstances {
                _ = comp.propertyOverrides
                _ = comp.propertyInstances
                _ = comp.referenceDesignatorIndex
                if let fp = comp.footprintInstance {
                    _ = fp.textOverrides
                    _ = fp.textInstances
                    _ = fp.resolvedItems
                }
            }
        } onChange: {
            Task { @MainActor in
                await self.rebuildNodes()
                self.startTrackingModelChanges()
            }
        }
    }

    // MARK: - Node Building

    /// The primary method to rebuild the node graph. It's called automatically by the tracking system.
    private func rebuildNodes() async {
        let design = projectManager.selectedDesign
        resetGraphIfNeeded(for: design)

        // 1. Rebuild and sort the canvas layers for this design.
        let unsortedCanvasLayers = design.layers.map { layerType in
            CanvasLayer(
                id: layerType.id,
                name: layerType.name,
                isVisible: true,
                color: NSColor(layerType.defaultColor).cgColor,
                zIndex: layerType.kind.zIndex,
                kind: layerType
            )
        }

        self.canvasLayers = unsortedCanvasLayers.sorted { (layerA, layerB) -> Bool in
            if layerA.zIndex != layerB.zIndex {
                return layerA.zIndex < layerB.zIndex
            }
            guard let typeA = layerA.kind as? LayerType, let sideA = typeA.side,
                  let typeB = layerB.kind as? LayerType, let sideB = typeB.side else {
                return false
            }
            return sideA.drawingOrder < sideB.drawingOrder
        }

        // 2. Build the FootprintNodes for all placed components.
        let footprintNodes: [FootprintNode] = design.componentInstances.compactMap { inst in
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement,
                  footprintInst.definition != nil else {
                return nil
            }
            let renderableTexts = self.generateRenderableTexts(for: inst)
            return FootprintNode(id: inst.id, instance: footprintInst, canvasLayers: self.canvasLayers, renderableTexts: renderableTexts)
        }

        // 3. Build the node representing the trace graph.
        let traceGraphNode = TraceGraphNode(graph: self.traceGraph)
        traceGraphNode.syncChildNodesFromModel(canvasLayers: self.canvasLayers)

        // 4. Combine all nodes into the final scene graph.
        canvasStore.setNodes(footprintNodes + [traceGraphNode])
    }

    /// Finds a node (and its children) recursively by its ID.
    func findNode(with id: UUID) -> BaseNode? {
        return canvasStore.nodes.findNode(with: id)
    }

    // MARK: - Private Helpers

    var primitives: [AnyCanvasPrimitive] {
        graph.components(AnyCanvasPrimitive.self).map { $0.1 }
    }

    var singleSelectedPrimitive: (id: NodeID, primitive: AnyCanvasPrimitive)? {
        guard canvasStore.selection.count == 1, let id = canvasStore.selection.first else { return nil }
        let nodeID = NodeID(id)
        guard let primitive = graph.component(AnyCanvasPrimitive.self, for: nodeID) else { return nil }
        return (nodeID, primitive)
    }

    func primitiveBinding(for id: UUID) -> Binding<AnyCanvasPrimitive>? {
        let nodeID = NodeID(id)
        guard graph.component(AnyCanvasPrimitive.self, for: nodeID) != nil else { return nil }
        let fallback = primitiveCache[nodeID] ?? AnyCanvasPrimitive.line(CanvasLine(start: .zero, end: .zero, strokeWidth: 1, layerId: nil))
        return Binding(
            get: { self.graph.component(AnyCanvasPrimitive.self, for: nodeID) ?? self.primitiveCache[nodeID] ?? fallback },
            set: {
                self.primitiveCache[nodeID] = $0
                self.graph.setComponent($0, for: nodeID)
            }
        )
    }

    /// Generates an array of `RenderableText` objects for a single `ComponentInstance`.
    private func generateRenderableTexts(for inst: ComponentInstance) -> [RenderableText] {
        // This logic is specific to the text defined on a footprint, which might differ from a symbol.
        // For now, we assume it uses the same `resolvedItems` as the symbol instance for properties.
        guard let footprintInst = inst.footprintInstance else { return [] }

        return footprintInst.resolvedItems.map { resolvedModel in
            // Use the ProjectManager's shared utility to get the final display string,
            // which correcly handles pending ECO values.
            let displayString = projectManager.generateString(for: resolvedModel, component: inst)
            return RenderableText(model: resolvedModel, text: displayString)
        }
    }

    private func resetGraphIfNeeded(for design: CircuitDesign) {
        guard activeDesignID != design.id else { return }
        activeDesignID = design.id
        primitiveCache.removeAll()
        graph.reset()
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
        case .reset(let nodes):
            addGraphPrimitives(from: nodes)
            removePrimitiveNodes(from: nodes)
            syncPrimitiveCacheFromGraph()
        case .nodesAdded(let nodes):
            addGraphPrimitives(from: nodes)
            removePrimitiveNodes(from: nodes)
            syncPrimitiveCacheFromGraph()
        case .nodesRemoved(let ids):
            for id in ids {
                graph.removeNode(NodeID(id))
            }
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelection = Set(selection.compactMap { id -> NodeID? in
                let nodeID = NodeID(id)
                return graph.hasAnyComponent(for: nodeID) ? nodeID : nil
            })
            if graph.selection != graphSelection {
                suppressGraphSelectionSync = true
                graph.selection = graphSelection
                suppressGraphSelectionSync = false
            }
        }
    }

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let selectionIDs = Set(selection.map { $0.rawValue })
            if canvasStore.selection != selectionIDs {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = selectionIDs
                    self.suppressGraphSelectionSync = false
                }
            }
        case .componentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(AnyCanvasPrimitive.self),
               let primitive = graph.component(AnyCanvasPrimitive.self, for: id) {
                primitiveCache[id] = primitive
            }
        case .nodeRemoved(let id):
            primitiveCache.removeValue(forKey: id)
        case .componentRemoved(let id, let componentKey):
            if componentKey == ObjectIdentifier(AnyCanvasPrimitive.self) {
                primitiveCache.removeValue(forKey: id)
            }
        default:
            break
        }
    }

    private func syncGraphNodeProxies(from nodes: [BaseNode]) {
        let selectableNodes = nodes.flattened().filter { $0.isSelectable }
        let newIDs = Set(selectableNodes.map { NodeID($0.id) })

        let removedIDs = graphNodeProxyIDs.subtracting(newIDs)
        for id in removedIDs {
            graph.removeComponent(GraphNodeComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        for node in selectableNodes {
            let nodeID = NodeID(node.id)
            if !graph.nodes.contains(nodeID) {
                graph.addNode(nodeID)
            }
            let kind: GraphNodeComponent.Kind = (node is TextNode) ? .text : .node
            graph.setComponent(GraphNodeComponent(kind: kind), for: nodeID)
        }

        graphNodeProxyIDs = newIDs
    }

    private func syncPrimitiveCacheFromGraph() {
        primitiveCache = Dictionary(
            uniqueKeysWithValues: graph.components(AnyCanvasPrimitive.self).map { ($0.0, $0.1) }
        )
    }

    private func addGraphPrimitives(from nodes: [BaseNode]) {
        for node in nodes {
            guard let primitiveNode = node as? PrimitiveNode else { continue }
            let graphID = NodeID(primitiveNode.id)
            graph.addNode(graphID)
            graph.setComponent(primitiveNode.primitive, for: graphID)
        }
    }

    private func removePrimitiveNodes(from nodes: [BaseNode]) {
        guard !suppressPrimitiveRemoval else { return }
        let primitiveIDs = Set(nodes.compactMap { ($0 as? PrimitiveNode)?.id })
        guard !primitiveIDs.isEmpty else { return }
        suppressPrimitiveRemoval = true
        canvasStore.removeNodes(ids: primitiveIDs, emitDelta: false)
        suppressPrimitiveRemoval = false
    }
}
