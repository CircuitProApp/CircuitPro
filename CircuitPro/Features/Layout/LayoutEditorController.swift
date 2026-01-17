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

    var items: [any CanvasItem] {
        get {
            let design = projectManager.selectedDesign
            return design.componentInstances + design.traces.points + design.traces.links
        }
        set {
            projectManager.selectedDesign.componentInstances = newValue.compactMap {
                $0 as? ComponentInstance
            }
            let points = newValue.compactMap { $0 as? TraceVertex }
            let links = newValue.compactMap { $0 as? TraceSegment }
            projectManager.selectedDesign.traces = Trace(points: points, links: links)
            projectManager.document.scheduleAutosave()
        }
    }

    // TEMP: Connections are disabled for now.
    // let graph = ConnectionGraph()
    // private var activeDesignID: UUID?
    // private var isSyncingTracesFromModel = false
    // private var isApplyingTraceChangesToModel = false

    // MARK: - Layout-Specific State

    /// The ID of the currently active layer for editing (e.g., for routing traces).
    var activeLayerId: UUID? = nil

    /// The list of layers relevant to the current design's layout, sorted for rendering.
    var canvasLayers: [any CanvasLayer] = []

    /// The engine for managing layout traces in the unified graph.
    // let traceEngine: TraceEngine

    var selectedTool: CanvasTool = CursorTool()

    // MARK: - Dependencies

    private let projectManager: ProjectManager


    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        refreshCanvasLayers(for: projectManager.selectedDesign)
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
                guard let pcbLayer = canvasLayer as? PCBLayer,
                      let layerKind = pcbLayer.layerKind
                else { return false }
                let kindMatches = layerKind == genericKind
                let sideMatches =
                    (side == .front && pcbLayer.layerSide == .front)
                    || (side == .back && pcbLayer.layerSide == .back)
                return kindMatches && sideMatches
            }) {
                copy.layerId = specificLayer.id
            }

            return copy
        }
    }

    // MARK: - Private Helpers
    private func refreshCanvasLayers(for design: CircuitDesign) {
        let unsortedCanvasLayers: [PCBLayer] = design.layers.map { layerType in
            PCBLayer(layerType: layerType)
        }

        self.canvasLayers = unsortedCanvasLayers.sorted { (layerA: PCBLayer, layerB: PCBLayer) -> Bool in
            if layerA.zIndex != layerB.zIndex {
                return layerA.zIndex < layerB.zIndex
            }
            let sideA = layerA.layerSide
            let sideB = layerB.layerSide
            if let sideA, let sideB, sideA != sideB {
                return sideA.drawingOrder < sideB.drawingOrder
            }
            return layerA.name.localizedCaseInsensitiveCompare(layerB.name) == .orderedAscending
        }
    }

    /*
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
    */
}
