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

    let graph = CanvasGraph()
    private var suppressGraphSelectionSync = false
    private var primitiveCache: [NodeID: AnyCanvasPrimitive] = [:]
    private var activeDesignID: UUID?
    private var isSyncingTracesFromModel = false
    private var isApplyingTraceChangesToModel = false
    private var isSyncingTextFromModel = false
    private var isApplyingTextChangesToModel = false

    // MARK: - Layout-Specific State

    /// The ID of the currently active layer for editing (e.g., for routing traces).
    var activeLayerId: UUID? = nil

    /// The list of layers relevant to the current design's layout, sorted for rendering.
    var canvasLayers: [CanvasLayer] = []

    /// The engine for managing layout traces in the unified graph.
    let traceEngine: TraceEngine

    var selectedTool: CanvasTool = CursorTool()

    // MARK: - Dependencies

    @ObservationIgnored private let projectManager: ProjectManager
    @ObservationIgnored private let document: CircuitProjectFileDocument

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.document = projectManager.document
        self.traceEngine = TraceEngine(graph: graph)
        self.traceEngine.onChange = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.handleTraceEngineChange()
            }
        }
        self.canvasStore.onDelta = { [weak self] delta in
            self?.handleStoreDelta(delta)
        }
        self.graph.onDelta = { [weak self] delta in
            self?.handleGraphDelta(delta)
        }

        // Start the automatic observation loops upon initialization.
        startTrackingStructureChanges()
        startTrackingTextChanges()
        startTrackingTraceChanges()

        Task {
            await self.rebuildNodes()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            // Rebuild layout nodes if the design or its components change.
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.selectedDesign.layers
        } onChange: {
            Task { @MainActor in
                await self.rebuildNodes()
                self.startTrackingStructureChanges()
            }
        }
    }

    private func startTrackingTextChanges() {
        withObservationTracking {
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
                    _ = fp.position
                    _ = fp.cardinalRotation
                }
            }
        } onChange: {
            Task { @MainActor in
                self.refreshFootprintTextNodes()
                self.refreshFootprintPadComponents()
                self.startTrackingTextChanges()
            }
        }
    }

    private func startTrackingTraceChanges() {
        withObservationTracking {
            _ = projectManager.selectedDesign.traces
        } onChange: {
            Task { @MainActor in
                if self.isApplyingTraceChangesToModel {
                    self.isApplyingTraceChangesToModel = false
                    self.startTrackingTraceChanges()
                    return
                }
                self.syncTracesFromModel()
                self.startTrackingTraceChanges()
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
            return FootprintNode(id: inst.id, instance: footprintInst, canvasLayers: self.canvasLayers)
        }

        // 3. Combine all nodes into the final scene graph.
        canvasStore.setNodes(footprintNodes)
        syncTracesFromModel()
        refreshFootprintTextNodes()
        refreshFootprintPadComponents()
    }

    func refreshFootprintTextNodes() {
        let design = projectManager.selectedDesign
        isSyncingTextFromModel = true
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement else {
                continue
            }

            let ownerPosition = footprintInst.position
            let ownerRotation = footprintInst.rotation
            let ownerTransform = CGAffineTransform(translationX: ownerPosition.x, y: ownerPosition.y)
                .rotated(by: ownerRotation)

            for resolvedModel in footprintInst.resolvedItems {
                let displayString = projectManager.generateString(for: resolvedModel, component: inst)
                let textID = GraphTextID.makeID(for: resolvedModel.source, ownerID: inst.id, fallback: resolvedModel.id)
                let nodeID = NodeID(textID)

                let worldPosition = resolvedModel.relativePosition.applying(ownerTransform)
                let worldAnchorPosition = resolvedModel.anchorPosition.applying(ownerTransform)
                let worldRotation = ownerRotation + resolvedModel.cardinalRotation.radians

                let component = GraphTextComponent(
                    resolvedText: resolvedModel,
                    displayText: displayString,
                    ownerID: inst.id,
                    target: .footprint,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    worldPosition: worldPosition,
                    worldRotation: worldRotation,
                    worldAnchorPosition: worldAnchorPosition,
                    layerId: nil,
                    showsAnchorGuides: true
                )

                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(component, for: nodeID)
                updatedIDs.insert(nodeID)
            }
        }

        let existingIDs = Set(graph.nodeIDs(with: GraphTextComponent.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(GraphTextComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }

        isSyncingTextFromModel = false
        canvasStore.setNodes(canvasStore.nodes, emitDelta: false)
    }

    private func refreshFootprintPadComponents() {
        let design = projectManager.selectedDesign
        var updatedIDs = Set<NodeID>()

        for inst in design.componentInstances {
            guard let footprintInst = inst.footprintInstance,
                  case .placed = footprintInst.placement,
                  let footprintDef = footprintInst.definition else {
                continue
            }

            let ownerPosition = footprintInst.position
            let ownerRotation = footprintInst.rotation

            for padDef in footprintDef.pads {
                let padID = GraphPadID.makeID(ownerID: inst.id, padID: padDef.id)
                let nodeID = NodeID(padID)
                let component = GraphPadComponent(
                    pad: padDef,
                    ownerID: inst.id,
                    ownerPosition: ownerPosition,
                    ownerRotation: ownerRotation,
                    layerId: nil,
                    isSelectable: false
                )

                if !graph.nodes.contains(nodeID) {
                    graph.addNode(nodeID)
                }
                graph.setComponent(component, for: nodeID)
                updatedIDs.insert(nodeID)
            }
        }

        let existingIDs = Set(graph.nodeIDs(with: GraphPadComponent.self))
        for id in existingIDs.subtracting(updatedIDs) {
            graph.removeComponent(GraphPadComponent.self, for: id)
            if !graph.hasAnyComponent(for: id) {
                graph.removeNode(id)
            }
        }
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

    private func resetGraphIfNeeded(for design: CircuitDesign) {
        guard activeDesignID != design.id else { return }
        activeDesignID = design.id
        primitiveCache.removeAll()
        isSyncingTracesFromModel = true
        traceEngine.reset()
        isSyncingTracesFromModel = false
        graph.reset()
    }

    private func handleStoreDelta(_ delta: CanvasStoreDelta) {
        switch delta {
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
        default:
            break
        }
    }

    private func handleGraphDelta(_ delta: UnifiedGraphDelta) {
        switch delta {
        case .selectionChanged(let selection):
            guard !suppressGraphSelectionSync else { return }
            let graphSelectionIDs = Set(selection.map { $0.rawValue })
            let nonGraphSelection = canvasStore.selection.filter { id in
                !graph.hasAnyComponent(for: NodeID(id))
            }
            let mergedSelection = Set(nonGraphSelection).union(graphSelectionIDs)
            if canvasStore.selection != mergedSelection {
                suppressGraphSelectionSync = true
                Task { @MainActor in
                    self.canvasStore.selection = mergedSelection
                    self.suppressGraphSelectionSync = false
                }
            }
        case .componentSet(let id, let componentKey):
            if componentKey == ObjectIdentifier(AnyCanvasPrimitive.self),
               let primitive = graph.component(AnyCanvasPrimitive.self, for: id) {
                primitiveCache[id] = primitive
            } else if componentKey == ObjectIdentifier(GraphTextComponent.self),
                      let component = graph.component(GraphTextComponent.self, for: id),
                      !isSyncingTextFromModel {
                applyGraphTextChange(component)
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

    private func applyGraphTextChange(_ component: GraphTextComponent) {
        guard !isApplyingTextChangesToModel else { return }
        guard let inst = projectManager.componentInstances.first(where: { $0.id == component.ownerID }) else { return }

        isApplyingTextChangesToModel = true
        inst.apply(component.resolvedText, for: component.target)
        document.scheduleAutosave()
        isApplyingTextChangesToModel = false
    }

    private func handleTraceEngineChange() {
        persistTraces()
        canvasStore.setNodes(canvasStore.nodes, emitDelta: false)
    }

    private func persistTraces() {
        guard !isSyncingTracesFromModel else { return }
        let design = projectManager.selectedDesign
        let newTraces = traceEngine.toTraceSegments()
        let existing = design.traces.map { $0.normalized() }.sorted { $0.sortKey < $1.sortKey }
        if newTraces == existing {
            return
        }
        isApplyingTraceChangesToModel = true
        design.traces = newTraces
        document.scheduleAutosave()
    }

    private func syncTracesFromModel() {
        isSyncingTracesFromModel = true
        let design = projectManager.selectedDesign
        let normalized = design.traces.map { $0.normalized() }
        traceEngine.build(from: normalized)
        isSyncingTracesFromModel = false
    }
}
