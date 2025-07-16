//
//  WorkbenchKeyCommandController.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/15/25.
//


import AppKit

/// Interprets Return / Esc / Delete / R and forwards them to the
/// appropriate gesture or tool helper.  Owns **no** transient state.
final class WorkbenchKeyCommandController {

    unowned let workbench:   WorkbenchView
    unowned let coordinator: WorkbenchInputCoordinator   // to reach rotation helper etc.

    init(workbench: WorkbenchView,
         coordinator: WorkbenchInputCoordinator) {
        self.workbench   = workbench
        self.coordinator = coordinator
    }

    /// Returns `true` when the key was consumed.
    func handle(_ e: NSEvent) -> Bool {
        let key = e.charactersIgnoringModifiers?.lowercased()

        switch key {

        // — Rotate tool or selection —————————————————————
        case "r":
            if var tool = workbench.selectedTool, tool.id != "cursor" {
                tool.handleRotate()
                workbench.selectedTool = tool
                workbench.previewView?.needsDisplay = true
            } else if let id = workbench.selectedIDs.first,
                      let center = workbench.elements
                                         .first(where: { $0.id == id })?
                                         .primitives.first?.position {
                coordinator.enterRotationMode(around: center)
            }
            return true

        // — Tool-specific Return ————————————————————————
        case "\r", "\u{3}":
            coordinator.handleReturnKeyPress()
            workbench.previewView?.needsDisplay = true
            return true

        // — Escape ————————————————————————————————
        case "\u{1b}":
            if var tool = workbench.selectedTool, tool.id != "cursor" {
                tool.handleEscape()
                workbench.selectedTool = tool
                workbench.previewView?.needsDisplay = true
                return true
            }

        // — Delete / Backspace ————————————————————————
        case String(UnicodeScalar(NSDeleteCharacter)!),
             String(UnicodeScalar(NSBackspaceCharacter)!):
            if var tool = workbench.selectedTool, tool.id != "cursor" {
                tool.handleBackspace()
                workbench.selectedTool = tool
                workbench.previewView?.needsDisplay = true
            } else {
                coordinator.deleteSelectedElements()
            }
            return true

        default:
            break
        }
        return false
    }
}
