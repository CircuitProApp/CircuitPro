import AppKit

final class RotationGestureController {

    unowned let controller: CanvasController
    private var pivotPoint: CGPoint?
    // This now stores the original rotation for each node in the gesture.
    private var originalRotations: [UUID: CGFloat] = [:]

    var active: Bool {
        return pivotPoint != nil
    }

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Starts a new rotation gesture around a given pivot point for the current selection.
    func begin(around pivot: CGPoint) {
        // Use the new node-based selection.
        guard !controller.selectedNodes.isEmpty else { return }
        
        pivotPoint = pivot
        originalRotations.removeAll()
        
        // Cache the original rotation for each selected node.
        for node in controller.selectedNodes {
            originalRotations[node.id] = node.rotation
        }
    }

    /// Commits the current rotation and ends the gesture.
    func commit() {
        // The nodes in the scene graph already have their final rotation from the last `update` call.
        // All we need to do is clean up our internal gesture state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Cancels the gesture and reverts all rotated nodes to their original state.
    func cancelAndRevert() {
        if active {
            // Iterate directly over the selected nodes and restore their original rotation.
            // Because nodes are classes, this mutation is reflected immediately.
            for node in controller.selectedNodes {
                if let originalRotation = originalRotations[node.id] {
                    node.rotation = originalRotation
                }
            }
        }
        
        // Reset state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Updates the rotation of all selected nodes based on the cursor's new position.
    func update(to cursor: CGPoint) {
        guard let pivot = self.pivotPoint else { return }

        // Calculate the new angle based on the cursor's position relative to the pivot.
        let currentAngle = atan2(cursor.y - pivot.y, cursor.x - pivot.x)
        
        // Snap the angle to 15-degree increments unless Shift is held down.
        let snappedAngle: CGFloat
        if !NSEvent.modifierFlags.contains(.shift) {
            let step: CGFloat = .pi / 12 // 15 degrees
            snappedAngle = round(currentAngle / step) * step
        } else {
            snappedAngle = currentAngle
        }

        // Apply the new rotation directly to the nodes involved in the gesture.
        for node in controller.selectedNodes {
            // Check originalRotations to ensure we only affect nodes from the initial set.
            if originalRotations[node.id] != nil {
                 node.rotation = snappedAngle
            }
        }
    }
}
