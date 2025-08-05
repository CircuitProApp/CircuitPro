import AppKit

/// Handles dragging selected nodes on the canvas.
/// This interaction should be placed after `SelectionInteraction` in the interaction stack,
/// as it relies on the selection state being up-to-date.
final class DragInteraction: CanvasInteraction {
    
    // MARK: - State
    
    private enum State {
        case ready
        /// - Parameters:
        ///   - origin: The initial mouse down point.
        ///   - anchorOriginalPosition: The starting position of the primary node being dragged.
        ///   - originalNodePositions: The starting positions of all selected nodes.
        case dragging(origin: CGPoint, anchorOriginalPosition: CGPoint, originalNodePositions: [UUID: CGPoint])
    }
    
    private var state: State = .ready
    private var didMove: Bool = false
    private let dragThreshold: CGFloat = 4.0

    // MARK: - CanvasInteraction
    
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // This interaction only runs when the selection tool is active.
        guard controller.selectedTool is CursorTool else {
            return false
        }
        
        // Ensure there are selected nodes to drag.
        guard !controller.selectedNodes.isEmpty else {
            return false
        }
        
        // Check if the hit node is part of the current selection.
        let tolerance = 5.0 / context.magnification
        guard let hit = context.sceneRoot.hitTest(point, tolerance: tolerance) else {
            return false
        }
        
        // Traverse up to find a selectable node that is actually in the selection.
        var nodeToDrag: BaseNode? = hit.node
        while let currentNode = nodeToDrag {
            if controller.selectedNodes.contains(where: { $0.id == currentNode.id }) {
                break // Found a selected node.
            }
            nodeToDrag = currentNode.parent
        }
        
        // If we didn't find a selected node under the cursor, do nothing.
        guard let anchorNode = nodeToDrag else {
            return false
        }
        
        // Prepare for dragging.
        var originalPositions: [UUID: CGPoint] = [:]
        for node in controller.selectedNodes {
            originalPositions[node.id] = node.position
        }
        
        self.state = .dragging(
            origin: point,
            anchorOriginalPosition: anchorNode.position,
            originalNodePositions: originalPositions
        )
        self.didMove = false
        
        // We've handled the event and are initiating a drag.
        return true
    }
    
    func mouseDragged(to point: CGPoint, context: RenderContext, controller: CanvasController) {
        guard case .dragging(let origin, let anchorOriginalPosition, let originalNodePositions) = self.state else {
            return
        }
        
        let rawMouseDelta = point - origin
        
        // Check if movement has exceeded the threshold to be considered a drag.
        if !didMove {
            let distance = hypot(rawMouseDelta.x, rawMouseDelta.y)
            if distance < dragThreshold / context.magnification {
                return
            }
            didMove = true
            // Here you could call a "begin drag" method on a model if needed.
        }
        
        // Calculate the final, snapped delta for movement.
        let finalDelta = calculateSnappedDelta(
            rawMouseDelta: rawMouseDelta,
            anchorOriginalPosition: anchorOriginalPosition,
            context: context
        )
        
        // Update positions of all selected nodes using the original positions and the final delta.
        for node in controller.selectedNodes {
            if let originalPosition = originalNodePositions[node.id] {
                node.position = originalPosition + finalDelta
            }
        }
    }
    
    func mouseUp(at point: CGPoint, context: RenderContext, controller: CanvasController) {
        if didMove {
            // Here you could call an "end drag" method on a model to commit changes.
        }
        
        // Reset state regardless of movement.
        self.state = .ready
        self.didMove = false
    }
    
    // MARK: - Snapping Logic
    
    private func calculateSnappedDelta(rawMouseDelta: CGPoint, anchorOriginalPosition: CGPoint, context: RenderContext) -> CGPoint {
        let config = context.environment.configuration
        let snapService = SnapService(
            gridSize: config.grid.spacing,
            isEnabled: config.snapping.isEnabled
        )
        
        // 1. Calculate the anchor's new theoretical position.
        let newAnchorPosition = anchorOriginalPosition + rawMouseDelta
        
        // 2. Snap that theoretical position to the grid.
        let snappedNewAnchorPosition = snapService.snap(newAnchorPosition)
        
        // 3. The final delta is the difference between the new snapped position and the original anchor position.
        return snappedNewAnchorPosition - anchorOriginalPosition
    }
}
