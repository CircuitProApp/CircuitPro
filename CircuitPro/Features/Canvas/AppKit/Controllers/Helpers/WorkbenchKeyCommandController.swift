import AppKit

/// Interprets key presses (Return, Esc, Delete, R) and forwards them to the
/// appropriate gesture or tool helper. Owns no transient state.
final class WorkbenchKeyCommandController {

    unowned let controller: CanvasController
    unowned let coordinator: WorkbenchInputCoordinator

    init(
        controller: CanvasController,
        coordinator: WorkbenchInputCoordinator
    ) {
        self.controller   = controller
        self.coordinator = coordinator
    }

    /// Returns `true` if the key press was handled.
    func handle(_ event: NSEvent) -> Bool {
        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        switch key {

        // 'R' key: Rotate the active tool or the current selection.
        case "r":
            // If there's an active tool, let it handle the rotation.
            if var tool = controller.selectedTool, tool.id != "cursor" {
                let context = coordinator.currentContext() // Tool might need context
                tool.handleRotate()
                controller.selectedTool = tool
            
            // Otherwise, if there's a selection, start a mouse-based rotation gesture.
            } else if let id = controller.selectedIDs.first,
                               let element = controller.elements.first(where: { $0.id == id }) {
                         
                         // --- THIS IS THE FIX ---
                         // Calculate the center point directly from public properties.
                         let boundingBox = element.boundingBox
                         let center = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
                         // --- END FIX ---
                         
                         coordinator.enterRotationMode(around: center)
                     }
            return true

        // 'Enter' or 'Return' key: Confirm the current tool action.
        case "\r", "\u{3}": // \u{3} is Enter on the numeric keypad
            coordinator.handleReturnKeyPress()
            return true

        // 'Escape' key: Cancel the current tool or gesture.
        case "\u{1b}":
            // If an active tool can handle escape, let it.
            if var tool = controller.selectedTool, tool.id != "cursor" {
                if !tool.handleEscape() {
                    // If the tool didn't handle it (e.g., nothing to clear),
                    // default to switching back to the cursor tool.
                    controller.selectedTool = AnyCanvasTool(CursorTool())
                }
            // If the rotation gesture is active, cancel it.
            } else if coordinator.isRotating {
                coordinator.cancelRotation()
            }
            return true

        // 'Delete' or 'Backspace' key.
        case String(UnicodeScalar(NSDeleteCharacter)!),
             String(UnicodeScalar(NSBackspaceCharacter)!):
            
            // If an active tool can handle backspace (e.g., deleting points), let it.
            if var tool = controller.selectedTool, tool.id != "cursor" {
                tool.handleBackspace()
                controller.selectedTool = tool
            // Otherwise, delete the currently selected elements.
            } else {
                coordinator.deleteSelectedElements()
            }
            return true

        default:
            // The key was not one of our commands.
            return false
        }
    }
}
