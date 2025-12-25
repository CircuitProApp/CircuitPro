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
    private(set) var nodes: [BaseNode] = []

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
            // Also rebuild if the active layer changes, as this can affect visuals.
            _ = self.activeLayerId
            // Also watch for changes from the sync manager for pending ECOs.
            _ = projectManager.syncManager.pendingChanges
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
        self.nodes = footprintNodes + [traceGraphNode]
    }

    /// Finds a node (and its children) recursively by its ID.
    func findNode(with id: UUID) -> BaseNode? {
        return nodes.findNode(with: id)
    }

    // MARK: - Private Helpers

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
}
