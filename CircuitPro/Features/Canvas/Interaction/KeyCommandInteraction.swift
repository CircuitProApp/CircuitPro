//
//  KeyCommandInteraction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/9/25.
//


import AppKit
import Carbon.HIToolbox // For kVK constants

/// An interaction that handles global keyboard commands like Escape, Return, Delete, and Rotate.
/// It prioritizes sending commands to the active tool first, falling back to global actions
/// (like deleting selected nodes) if the tool doesn't handle the command.
struct KeyCommandInteraction: CanvasInteraction {

    func keyDown(with event: NSEvent, context: RenderContext, controller: CanvasController) -> Bool {
        // Use key codes for non-character keys like Escape, Return, and Delete.
        switch Int(event.keyCode) {
            
        case kVK_Escape:
            return handleEscape(controller: controller)
            
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return handleReturn(context: context, controller: controller)

        case kVK_Delete, kVK_ForwardDelete:
            return handleDelete(controller: controller)

        default:
            // For character keys like 'r', check the character itself.
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return false
            }
            if chars == "r" {
                return handleRotate(controller: controller)
            }
            return false
        }
    }

    /// Handles the Escape key.
    /// It first offers the event to the active tool. If the tool doesn't handle it,
    /// it deselects the tool, effectively returning to the default cursor state.
    private func handleEscape(controller: CanvasController) -> Bool {
        guard let tool = controller.selectedTool, !(tool is CursorTool) else {
            // If there's no special tool active, Escape does nothing.
            return false
        }
        
        // If the tool clears its own state (e.g., a multi-point line tool), it returns true.
        if tool.handleEscape() {
            // The tool handled it, nothing more to do.
        } else {
            // If the tool didn't handle it, we assume the user wants to cancel the tool itself.
            // Setting the tool to nil will cause the view to fall back to the default tool.
            controller.selectedTool = nil
        }
        return true // We consumed the Escape key event.
    }
    
    /// Handles the Return/Enter key.
    /// This is typically used to finalize a tool's operation.
    private func handleReturn(context: RenderContext, controller: CanvasController) -> Bool {
        guard let tool = controller.selectedTool else { return false }
        
        let result = tool.handleReturn()
        
        // This logic is similar to ToolInteraction's mouseDown, handling the case
        // where a tool's action results in a new node.
        guard case .newNode(let newNode) = result else {
            // The tool handled the key but didn't produce a new node.
            return result != .noResult
        }
        
        // Add the new node to the scene and notify the document of the change.
        controller.sceneRoot.addChild(newNode)
        
        return true
    }
    
    /// Handles the Delete/Backspace key.
    /// It first offers the event to the active tool (e.g., to delete the last point).
    /// If the tool doesn't handle it, it deletes the currently selected nodes.
    private func handleDelete(controller: CanvasController) -> Bool {
        // Prioritize the active tool.
        if let tool = controller.selectedTool, !(tool is CursorTool) {
            // Allow the tool to perform a "backspace" action.
            tool.handleBackspace()
            return true // Assume the tool handled it.
        }
        
        // If no tool handled it, perform the standard "delete selection" action.
        guard !controller.selectedNodes.isEmpty else { return false }
        
        // Remove the selected nodes from the scene graph.
        let selectedIDs = Set(controller.selectedNodes.map { $0.id })
        controller.sceneRoot.children.removeAll { selectedIDs.contains($0.id) }
        
        // Clear the selection.
        controller.setSelection(to: [])
        
        return true
    }
    
    /// Handles the 'R' key for rotation.
    /// It first offers the event to the active tool. If no tool handles it,
    /// it attempts to rotate the currently selected nodes.
    private func handleRotate(controller: CanvasController) -> Bool {
        // Prioritize the active tool.
        if let tool = controller.selectedTool, !(tool is CursorTool) {
            tool.handleRotate()
            return true
        }
        
        // Fallback: Rotate the selected nodes.
        guard !controller.selectedNodes.isEmpty else { return false }
        
        // WARNING: This assumes your concrete node classes that should be rotatable
        // have a working 'set' implementation for their `rotation` property.
        // The provided `BaseNode` has a no-op setter, so you must override it.
        controller.selectedNodes.forEach { node in
            // Example: Rotate by 90 degrees (π/2 radians).
            node.rotation += .pi / 2
        }
        
        return true
    }
}
