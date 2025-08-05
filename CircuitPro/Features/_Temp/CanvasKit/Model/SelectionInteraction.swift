//
//  SelectionInteraction.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//


import AppKit

/// Handles node selection logic when the cursor is active.
struct SelectionInteraction: CanvasInteraction {
    func mouseDown(at point: CGPoint, context: RenderContext, controller: CanvasController) -> Bool {
        // Only interested if the cursor tool is active.
        guard controller.selectedTool?.id == "cursor" else { return false }
        
        let tolerance = 5.0 / context.magnification
        let hitTarget = context.sceneRoot.hitTest(point, tolerance: tolerance)
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        
        if let hit = hitTarget, let hitID = hit.selectableID {
            // Clicked on an object
            if modifierFlags.contains(.shift) {
                // Shift-click to add/remove from selection
                if let index = controller.selectedNodes.firstIndex(where: { $0.id == hitID }) {
                    controller.selectedNodes.remove(at: index)
                } else if let node = findNode(with: hitID, in: controller.sceneRoot) {
                    controller.selectedNodes.append(node)
                }
            } else {
                // Normal click to select a single node
                if !controller.selectedNodes.contains(where: { $0.id == hitID }) {
                     if let node = findNode(with: hitID, in: controller.sceneRoot) {
                        controller.selectedNodes = [node]
                    }
                }
            }
        } else {
            // Clicked on empty space
            if !modifierFlags.contains(.shift) && !controller.selectedNodes.isEmpty {
                controller.selectedNodes.removeAll()
            }
        }
        
        // Propagate selection changes back to SwiftUI
        controller.onUpdateSelectedNodes?(controller.selectedNodes)
        
        // IMPORTANT: Return false. We want other interactions (like Drag) to be
        // able to act on this same click event.
        return false
    }
    
    private func findNode(with id: UUID, in root: any CanvasNode) -> (any CanvasNode)? {
        if root.id == id { return root }
        for child in root.children {
            if let found = findNode(with: id, in: child) { return found }
        }
        return nil
    }
}