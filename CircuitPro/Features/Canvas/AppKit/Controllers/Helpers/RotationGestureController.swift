import AppKit

/// Tracks a mouse-based rotation gesture for the current selection.
final class RotationGestureController {

    unowned let controller: CanvasController

    // The center point around which the rotation occurs.
    private var pivotPoint: CGPoint?
    
    // The initial angle of the mouse relative to the pivot when the gesture began.
    // This allows for rotating objects that already have a non-zero rotation.
    private var startAngle: CGFloat = 0
    
    // A dictionary to store the original rotation of each element being rotated.
    private var originalRotations: [UUID: CGFloat] = [:]

    var active: Bool {
        return pivotPoint != nil
    }

    init(controller: CanvasController) {
        self.controller = controller
    }

    /// Starts a new rotation gesture, invoked from a key command.
    /// - Parameter pivot: The point in world coordinates to rotate the selection around.
    func begin(at pivot: CGPoint) {
        guard !controller.selectedIDs.isEmpty else { return }
        
        pivotPoint = pivot
        
        // Store the original rotation of every selected element.
        originalRotations.removeAll()
        for element in controller.elements where controller.selectedIDs.contains(element.id) {
            originalRotations[element.id] = element.transformable.rotation
        }
    }

    /// Cancels the gesture, for example, when the user presses Escape.
    func cancel() {
        // If the gesture was active, revert elements to their original rotation.
        if active, !originalRotations.isEmpty {
            var updatedElements = controller.elements
            for i in updatedElements.indices {
                if let originalRotation = originalRotations[updatedElements[i].id] {
                    updatedElements[i].setRotation(originalRotation)
                }
            }
            controller.elements = updatedElements
        }
        
        // Reset all transient state.
        pivotPoint = nil
        originalRotations.removeAll()
    }

    /// Updates the rotation of the selected elements based on the cursor's position.
    /// This is called continuously from the `mouseMoved` or `mouseDragged` event handler.
    func update(to cursor: CGPoint) {
        guard let pivot = self.pivotPoint else { return }

        // Calculate the angle of the mouse cursor relative to the pivot point.
        let currentAngle = atan2(cursor.y - pivot.y, cursor.x - pivot.x)

        // Snap the angle to 15-degree increments unless Shift is held down.
        let snappedAngle: CGFloat
        if !NSEvent.modifierFlags.contains(.shift) {
            let step: CGFloat = .pi / 12 // 15 degrees
            snappedAngle = round(currentAngle / step) * step
        } else {
            snappedAngle = currentAngle
        }

        // Apply the new rotation to all selected elements.
        var updatedElements = controller.elements
        for i in updatedElements.indices {
            // Check if the element is in the set of items being rotated.
            if let _ = originalRotations[updatedElements[i].id] {
                 updatedElements[i].setRotation(snappedAngle)
            }
        }
        
        // Mutate the controller's state directly.
        controller.elements = updatedElements
    }
}
