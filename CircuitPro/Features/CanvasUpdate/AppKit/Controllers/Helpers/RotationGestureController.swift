import AppKit

final class RotationGestureController {

    unowned let controller: CanvasController
    private var pivotPoint: CGPoint?
    private var originalRotations: [UUID: CGFloat] = [:]

    var active: Bool {
        return pivotPoint != nil
    }

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Starts a new rotation gesture around a given pivot point for the current selection.
    func begin(around pivot: CGPoint) {
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
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Cancels the gesture and reverts all rotated nodes to their original state.
    func cancelAndRevert() {
        guard active else { return }
        
        // --- THIS IS THE FIX ---
        // We must iterate by index to get a mutable reference to each node
        // in the controller's array, allowing us to set its rotation.
        for i in controller.selectedNodes.indices {
            let node = controller.selectedNodes[i]
            if let originalRotation = originalRotations[node.id] {
                controller.selectedNodes[i].rotation = originalRotation
            }
        }
        
        // Reset state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Updates the rotation of all selected nodes based on the cursor's new position.
    func update(to cursor: CGPoint) {
        guard let pivot = self.pivotPoint else { return }

        let currentAngle = atan2(cursor.y - pivot.y, cursor.x - pivot.x)
        
        let snappedAngle: CGFloat
        if !NSEvent.modifierFlags.contains(.shift) {
            let step: CGFloat = .pi / 12 // 15 degrees
            snappedAngle = round(currentAngle / step) * step
        } else {
            snappedAngle = currentAngle
        }

        // --- AND THIS IS THE FIX ---
        // Same as above. We use an index-based loop to apply the new rotation.
        for i in controller.selectedNodes.indices {
            let node = controller.selectedNodes[i]
            // Check originalRotations to ensure we only affect nodes from the initial set.
            if originalRotations[node.id] != nil {
                 controller.selectedNodes[i].rotation = snappedAngle
            }
        }
    }
}
