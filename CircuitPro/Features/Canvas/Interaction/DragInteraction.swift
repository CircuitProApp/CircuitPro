import AppKit

/// Handles dragging selected nodes on the canvas.
/// This interaction has special logic to handle dragging schematic connections via the `SchematicGraph` model.
final class DragInteraction: CanvasInteraction {
    
    private enum State {
        case ready
        /// Dragging standard scene nodes by updating their position.
        case draggingNodes(origin: CGPoint, originalNodePositions: [UUID: CGPoint])
        /// Dragging parts of a schematic graph, which is a model-driven operation.
        case draggingGraph(graph: SchematicGraph, origin: CGPoint)
    }
    
    private var state: State = .ready
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    
    var wantsRawInput: Bool { true }
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        guard controller.selectedTool is CursorTool,
              !controller.selectedNodes.isEmpty else {
            return false
        }
        
        let tolerance = 5.0 / context.magnification
        guard let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) else {
            return false
        }
        
        // First, ensure the node that was hit is actually part of the current selection.
        var nodeToDrag: BaseNode? = hit.node
        var hitNodeIsSelected = false
        while let currentNode = nodeToDrag {
            if controller.selectedNodes.contains(where: { $0.id == currentNode.id }) {
                hitNodeIsSelected = true
                break
            }
            nodeToDrag = currentNode.parent
        }
        
        guard hitNodeIsSelected else { return false }
        
        // --- Special Case: Schematic Graph Dragging ---
        // If a schematic graph exists, check if the drag should be delegated to it.
        if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            let selectedIDs = Set(controller.selectedNodes.map { $0.id })
            
            // Attempt to initiate a drag operation on the graph model.
            if graphNode.graph.beginDrag(selectedIDs: selectedIDs) {
                self.state = .draggingGraph(graph: graphNode.graph, origin: point)
                self.didMove = false
                return true
            }
        }
        
        // --- Fallback: Generic Node Dragging ---
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            originalPositions[node.id] = node.position
        }
        
        self.state = .draggingNodes(origin: point, originalNodePositions: originalPositions)
        self.didMove = false
        
        return true
    }
    
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        switch state {
        case .ready:
            return
            
        case .draggingGraph(let graph, let origin):
            let rawDelta = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
            
            if !didMove {
                if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification {
                    return
                }
                didMove = true
            }
            
            // Pass the raw delta to the graph model to compute new positions.
            graph.updateDrag(by: CGPoint(x: rawDelta.dx, y: rawDelta.dy))
            
            // The model has changed, so trigger a redraw of the canvas.
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.onNeedsRedraw?()
            }

        case .draggingNodes(let origin, let originalNodePositions):
            let rawDelta = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
            
            if !didMove {
                if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification {
                    return
                }
                didMove = true
            }
            
            let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
            
            for node in controller.selectedNodes {
                if let originalPosition = originalNodePositions[node.id] {
                    node.position = originalPosition + CGPoint(x: finalDelta.dx, y: finalDelta.dy)
                }
            }
        }
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        switch self.state {
        case .draggingGraph(let graph, _):
            // Always end the drag to clean up state and normalize the graph.
            graph.endDrag()
            
            // After normalization, the graph's topology may have changed.
            // We must sync the scene graph to reflect the final model state.
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.syncChildNodesFromModel()
            }
            
        case .draggingNodes:
            if didMove {
                // Future: Commit transaction for undo/redo
            }
            
        case .ready:
            break
        }
        
        self.state = .ready
        self.didMove = false
    }
}
