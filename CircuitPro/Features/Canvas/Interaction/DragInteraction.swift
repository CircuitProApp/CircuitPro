import AppKit

/// Handles dragging selected nodes on the canvas.
final class DragInteraction: CanvasInteraction {
    
    private enum State {
        case ready
        case dragging(origin: CGPoint, originalNodePositions: [UUID: CGPoint])
    }
    
    private var state: State = .ready
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This method receives the already-processed point from the pipeline,
        // which is perfect for hit-testing and setting the drag origin.
        guard controller.selectedTool is CursorTool,
              !controller.selectedNodes.isEmpty else {
            return false
        }
        
        let tolerance = 5.0 / context.magnification
        guard let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) else {
            return false
        }
        
        var nodeToDrag: BaseNode? = hit.node
        while let currentNode = nodeToDrag {
            if controller.selectedNodes.contains(where: { $0.id == currentNode.id }) {
                break
            }
            nodeToDrag = currentNode.parent
        }
        
        guard nodeToDrag != nil else { return false }
        
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            originalPositions[node.id] = node.position
        }
        
        self.state = .dragging(origin: point, originalNodePositions: originalPositions)
        self.didMove = false
        
        return true
    }
    
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, let originalNodePositions) = self.state else {
            return
        }
        
        // The `point` and `origin` are already processed by the pipeline.
        let rawDelta = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
        
        if !didMove {
            if hypot(rawDelta.dx, rawDelta.dy) < dragThreshold / context.magnification {
                return
            }
            didMove = true
        }
        
        // --- THIS IS THE FIX ---
        // Ask the context's provider to perform the delta snap.
        // The interaction doesn't know 'how' snapping works, only that it needs it.
        let finalDelta = context.snapProvider.snap(delta: rawDelta, context: context)
        
        for node in controller.selectedNodes {
            if let originalPosition = originalNodePositions[node.id] {
                node.position = originalPosition + CGPoint(x: finalDelta.dx, y: finalDelta.dy)
            }
        }
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if didMove {
            // Future: Commit transaction for undo/redo
        }
        self.state = .ready
        self.didMove = false
    }
    
    // The old, private `calculateSnappedDelta` method is now completely gone.
}
