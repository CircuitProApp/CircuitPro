//
//  WorkspaceContainer.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import SwiftUI

/// Holds the project model and editor session in stable @State storage.
struct WorkspaceContainer: View {
    let document: CircuitProjectFileDocument
    let documentID: DocumentID

    @State private var projectManager: ProjectManager
    @State private var editorSession: EditorSession

    init(document: CircuitProjectFileDocument, documentID: DocumentID) {
        self.document = document
        self.documentID = documentID
        let manager = ProjectManager(document: document)
        _projectManager = State(initialValue: manager)
        _editorSession = State(initialValue: EditorSession(projectManager: manager))
    }

    var body: some View {
        WorkspaceView()
            .environment(\.projectManager, projectManager)
            .environment(\.editorSession, editorSession)
    }
}
