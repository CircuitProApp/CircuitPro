import AppKit


/// Handles dragging selected nodes on the canvas.
/// This interaction has special logic to handle dragging schematic wire via the `WireGraph` model.
final class DragInteraction: CanvasInteraction {
    
    private struct DraggingState {
        let origin: CGPoint
        let originalNodePositions: [UUID: CGPoint]
        let graph: WireGraph?
    }
    
    private var state: DraggingState?
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    
    var wantsRawInput: Bool { true }
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        self.state = nil
        guard controller.selectedTool is CursorTool, !controller.selectedNodes.isEmpty else { return false }
        
        let tolerance = 5.0 / context.magnification
        guard let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) else { return false }
        
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

        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes where node is Transformable {
            originalPositions[node.id] = node.position
        }
        
        var activeGraph: WireGraph? = nil
        if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
            let selectedIDs = Set(controller.selectedNodes.map { $0.id })
            if graphNode.graph.beginDrag(selectedIDs: selectedIDs) {
                activeGraph = graphNode.graph
            }
        }
        
        self.state = DraggingState(origin: point, originalNodePositions: originalPositions, graph: activeGraph)
        self.didMove = false
        
        return true
    }
    
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard let currentState = self.state else { return }
        
        let rawDelta = CGVector(dx: point.x - currentState.origin.x, dy: point.y - currentState.origin.y)
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification { return }
            didMove = true
        }
        
        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        let deltaPoint = CGPoint(x: finalDelta.dx, y: finalDelta.dy)
        
        for node in controller.selectedNodes {
            if let originalPosition = currentState.originalNodePositions[node.id] {
                node.position = originalPosition + deltaPoint
            }
        }
        
        if let graph = currentState.graph {
            graph.updateDrag(by: deltaPoint)
            
            // --- THIS IS THE FIX ---
            // After the graph model's topology changes, we must immediately find the
            // SchematicGraphNode and tell it to rebuild its visual children. This
            // creates the WireNodes for the new L-bend segments instantly.
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                graphNode.syncChildNodesFromModel()
            }
        }
        
        // A redraw is now implicitly handled by graphNode.syncChildNodesFromModel() which calls onNeedsRedraw.
        // But calling it here ensures redraw even if only symbols are moved.
        controller.redraw()
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if let graph = self.state?.graph {
            graph.endDrag()
            if let graphNode = context.sceneRoot.children.first(where: { $0 is SchematicGraphNode }) as? SchematicGraphNode {
                // Final sync after normalization.
                graphNode.syncChildNodesFromModel()
            }
        }
        
        if didMove {
            // Persist changes for any nodes that were moved.
            for node in controller.selectedNodes {
                // If the dragged node is an anchored text, tell it to commit its
                // state back to its owning SymbolInstance model.
                if let textNode = node as? AnchoredTextNode {
                    textNode.commitChanges()
                }
            }
            
            // Notify the document that the model has changed and needs saving.
            controller.onModelDidChange?()
        }
        
        self.state = nil
        self.didMove = false
    }
}
