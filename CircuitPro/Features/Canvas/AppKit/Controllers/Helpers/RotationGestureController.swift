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

    /// Starts a new rotation gesture around a given pivot point.
    func begin(around pivot: CGPoint) {
        guard !controller.selectedIDs.isEmpty else { return }
        
        pivotPoint = pivot
        originalRotations.removeAll()
        for element in controller.elements where controller.selectedIDs.contains(element.id) {
            originalRotations[element.id] = element.transformable.rotation
        }
    }

    /// **NEW:** Commits the current rotation and ends the gesture.
    /// This is called when the user clicks the mouse to confirm the new angle.
    func commit() {
        // The controller's `elements` array already has the final rotation from the last `update`.
        // All we need to do is clean up our internal gesture state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// **NEW:** Cancels the gesture and reverts all changes.
    /// This is called when the user presses the Escape key.
    func cancelAndRevert() {
        if active, !originalRotations.isEmpty {
            var updatedElements = controller.elements
            for i in updatedElements.indices {
                if let originalRotation = originalRotations[updatedElements[i].id] {
                    updatedElements[i].setRotation(originalRotation)
                }
            }
            controller.elements = updatedElements
            controller.onUpdateElements?(updatedElements) // Inform SwiftUI of the revert
        }
        
        // Reset state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Updates the rotation based on the cursor's new position.
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

        var updatedElements = controller.elements
        for i in updatedElements.indices {
            if originalRotations[updatedElements[i].id] != nil {
                 updatedElements[i].setRotation(snappedAngle)
            }
        }
        controller.elements = updatedElements
        controller.onUpdateElements?(updatedElements)
    }
}
