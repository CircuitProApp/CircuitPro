//
//  EditorSessionKey.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import SwiftUI

private struct EditorSessionKey: EnvironmentKey {
    @MainActor
    static var defaultValue: EditorSession {
        EditorSession(
            projectManager: ProjectManager(
                document: .init(newWithName: "")
            )
        )
    }
}

extension EnvironmentValues {
    @MainActor
    var editorSession: EditorSession {
        get { self[EditorSessionKey.self] }
        set { self[EditorSessionKey.self] = newValue }
    }
}
