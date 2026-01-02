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

    var selectedNodeIDs: Set<UUID> {
        get { activeCanvasStore.selection }
        set { activeCanvasStore.selection = newValue }
    }

    var activeEditorController: EditorController {
        switch selectedEditor {
        case .schematic: return schematicController
        case .layout: return layoutController
        }
    }

    var activeCanvasStore: CanvasStore {
        switch selectedEditor {
        case .schematic: return schematicController.canvasStore
        case .layout: return layoutController.canvasStore
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
