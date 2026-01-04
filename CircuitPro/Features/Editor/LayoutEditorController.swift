import Observation
import SwiftUI

/// The high-level controller for the layout editor.
///
/// This class is the single source of truth for the layout canvas's view state. It observes the
/// core `ProjectManager` data and is responsible for building the renderable item list
/// of footprints and traces. It also manages layout-specific UI state like the active layer.
@MainActor
@Observable
final class LayoutEditorController {

    var items: [any CanvasItem] = []

    let graph = ConnectionGraph()
    private var activeDesignID: UUID?
    private var isSyncingTracesFromModel = false
    private var isApplyingTraceChangesToModel = false

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

        // Start the automatic observation loops upon initialization.
        startTrackingStructureChanges()
        startTrackingTextChanges()
        startTrackingTransformChanges()
        startTrackingTraceChanges()

        Task {
            await self.rebuildItems()
        }
    }

    private func startTrackingStructureChanges() {
        withObservationTracking {
            // Rebuild layout nodes if the design or its components change.
            _ = projectManager.selectedDesign
            _ = projectManager.componentInstances
            _ = projectManager.selectedDesign.layers
            for comp in projectManager.componentInstances {
                if let footprint = comp.footprintInstance {
                    _ = footprint.placement
                    _ = footprint.definitionUUID
                }
            }
        } onChange: {
            Task { @MainActor in
                await self.rebuildItems()
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
                }
            }
        } onChange: {
            Task { @MainActor in
                let design = self.projectManager.selectedDesign
                self.items = self.buildItems(from: design)
                self.startTrackingTextChanges()
            }
        }
    }

    private func startTrackingTransformChanges() {
        withObservationTracking {
            for comp in projectManager.componentInstances {
                if let fp = comp.footprintInstance {
                    _ = fp.position
                    _ = fp.cardinalRotation
                }
            }
        } onChange: {
            Task { @MainActor in
                let design = self.projectManager.selectedDesign
                self.items = self.buildItems(from: design)
                self.startTrackingTransformChanges()
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

    // MARK: - Item Building

    /// The primary method to rebuild the item list. It's called automatically by the tracking system.
    private func rebuildItems() async {
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
                let typeB = layerB.kind as? LayerType, let sideB = typeB.side
            else {
                return false
            }
            return sideA.drawingOrder < sideB.drawingOrder
        }

        syncTracesFromModel()
        items = buildItems(from: design)
    }

    private func buildItems(from design: CircuitDesign) -> [any CanvasItem] {
        design.componentInstances.filter { inst in
            guard let footprint = inst.footprintInstance else { return false }
            if case .placed = footprint.placement { return true }
            return false
        }
    }

    private func resolveFootprintPrimitives(
        for instance: FootprintInstance, definition: FootprintDefinition
    ) -> [AnyCanvasPrimitive] {
        guard case .placed(let side) = instance.placement else {
            return definition.primitives
        }

        return definition.primitives.map { primitive in
            var copy = primitive
            guard let genericLayerID = copy.layerId,
                let genericKind = LayerKind.allCases.first(where: { $0.stableId == genericLayerID })
            else {
                return copy
            }

            if let specificLayer = canvasLayers.first(where: { canvasLayer in
                guard let layerType = canvasLayer.kind as? LayerType else { return false }
                let kindMatches = layerType.kind == genericKind
                let sideMatches =
                    (side == .front && layerType.side == .front)
                    || (side == .back && layerType.side == .back)
                return kindMatches && sideMatches
            }) {
                copy.layerId = specificLayer.id
            }

            return copy
        }
    }

    // MARK: - Private Helpers
    private func resetGraphIfNeeded(for design: CircuitDesign) {
        guard activeDesignID != design.id else { return }
        activeDesignID = design.id
        isSyncingTracesFromModel = true
        traceEngine.reset()
        isSyncingTracesFromModel = false
        graph.reset()
    }

    private func handleTraceEngineChange() {
        persistTraces()
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
