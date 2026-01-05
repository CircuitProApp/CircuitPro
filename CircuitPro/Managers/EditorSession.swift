//
//  EditorSession.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Observation
import Foundation

@MainActor
@Observable
final class EditorSession {

    var projectManager: ProjectManager
    var schematicController: SchematicEditorController
    var layoutController: LayoutEditorController

    var selectedEditor: EditorType = .schematic
    var selectedNetIDs: Set<UUID> = []
    var schematicSelection: Set<UUID> = []
    var layoutSelection: Set<UUID> = []

    var selectedItemIDs: Set<UUID> {
        get {
            switch selectedEditor {
            case .schematic:
                return schematicSelection
            case .layout:
                return layoutSelection
            }
        }
        set {
            switch selectedEditor {
            case .schematic:
                schematicSelection = newValue
            case .layout:
                layoutSelection = newValue
            }
        }
    }

    var changeSource: ChangeSource {
        selectedEditor.changeSource
    }

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.schematicController = SchematicEditorController(projectManager: projectManager)
        self.layoutController = LayoutEditorController(projectManager: projectManager)
    }
}
