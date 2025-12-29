//
//  ProjectManagerContainer.swift
//  CircuitPro
//
//  Wrapper view that holds ProjectManager in @State to ensure stable identity
//  across SwiftUI re-evaluations (e.g., layout changes, resize).
//

import SwiftUI

/// A container that holds a stable ProjectManager instance in @State.
/// This prevents the ProjectManager (and its controllers) from being
/// recreated during layout changes like sidebar/inspector resize.
struct ProjectManagerContainer: View {
    let document: CircuitProjectFileDocument
    let documentID: DocumentID

    @State private var projectManager: ProjectManager?

    var body: some View {
        Group {
            if let manager = projectManager {
                WorkspaceView()
                    .environment(\.projectManager, manager)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if projectManager == nil {
                projectManager = ProjectManager(document: document)
            }
        }
    }
}
