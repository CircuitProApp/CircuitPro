//
//  CircuitProApp.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 4/01/25.
//

import SwiftUI
import SwiftData

@main
struct CircuitProApp: App {
    var body: some Scene {
        WelcomeWindowScene()

        WindowGroup(for: DocumentID.self) { $docID in
            if let id = docID, let doc = DocumentRegistry.shared.document(for: id) {
                WorkspaceView(document: doc)
                    .modelContainer(ModelContainerManager.shared.container)
                    .environment(\.projectManager,
                        ProjectManager(project: doc.model,
                                       modelContext: ModelContainerManager.shared.container.mainContext))
                    .focusedSceneValue(\.activeDocumentID, id)
                    .onDisappear { DocumentRegistry.shared.close(id: id) }
            } else {
                // Avoid showing a placeholder window; close it if it appears unintentionally.
                AutoClosingEmptyWindow()
            }
        }
        .defaultSize(width: 1000, height: 700)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CircuitProCommands()
        }

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .modelContainer(ModelContainerManager.shared.container)
        }

        AboutWindowScene()
    }
}
