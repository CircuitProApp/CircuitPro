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
        // ... (This function remains mostly the same, but we simplify the state) ...
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
        
        guard nodeToDrag != nil else {
            return false
        }
        
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            originalPositions[node.id] = node.position
        }
        
        // We no longer need to store the anchor's original position in the state.
        self.state = .dragging(origin: point, originalNodePositions: originalPositions)
        self.didMove = false
        
        return true
    }
    
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, let originalNodePositions) = self.state else {
            return
        }
        
        let rawMouseDelta = point - origin
        
        if !didMove {
            if hypot(rawMouseDelta.x, rawMouseDelta.y) < dragThreshold / context.magnification {
                return
            }
            didMove = true
        }
        
        // Calculate the final, snapped delta for movement. The signature is now simpler.
        let finalDelta = calculateSnappedDelta(rawMouseDelta: rawMouseDelta, context: context)
        
        for node in controller.selectedNodes {
            if let originalPosition = originalNodePositions[node.id] {
                node.position = originalPosition + finalDelta
            }
        }
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if didMove {
            // Commit changes...
        }
        self.state = .ready
        self.didMove = false
    }
    
    // MARK: - Snapping Logic
    
    private func calculateSnappedDelta(rawMouseDelta: CGPoint, context: RenderContext) -> CGPoint {
        let config = context.environment.configuration
        let snapService = SnapService(
            gridSize: config.grid.spacing.rawValue,
            isEnabled: config.snapping.isEnabled
        )
        
        // If snapping is disabled, or grid size is invalid, return the raw movement delta.
        guard snapService.isEnabled, snapService.gridSize > 0 else {
            return rawMouseDelta
        }

        // --- THE FIX ---
        // Instead of snapping the absolute final position, we now snap the
        // x and y components of the movement vector itself. This preserves
        // the original offset from the grid.
        let snappedDeltaX = snapService.snapDelta(rawMouseDelta.x)
        let snappedDeltaY = snapService.snapDelta(rawMouseDelta.y)
        
        return CGPoint(x: snappedDeltaX, y: snappedDeltaY)
    }
}
