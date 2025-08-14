//
//  CircuitProApp.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 4/01/25.
//

import SwiftUI
import SwiftData
import WelcomeWindow
import AboutWindow

import SwiftUI
import SwiftData

@main
struct CircuitProApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        _ = CircuitProjectDocumentController.shared
    }

    var body: some Scene {
        Group {
            WelcomeWindow(
                actions: { dismiss in
                    WelcomeWindowActions(dismiss: dismiss)
                },
                onDrop: { url, dismiss in
                    Task { @MainActor in
                        NSDocumentController.shared.openDocument(at: url, display: false) { id in
                            openWindow(value: id) // NOTE: value-based open, no id: label
                            dismiss()
                        } onError: { _ in }
                    }
                }
            )

            AboutWindow(actions: {}, footer: { AboutFooterView() })
        }
        .commands {
            CircuitProCommands()
        }

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .modelContainer(ModelContainerManager.shared.container)
        }

        // macOS 14+: typed window group for value-based routing
        WindowGroup(for: DocumentID.self) { $docID in
            if let id = docID, let doc = DocumentRegistry.shared.document(for: id) {
                WorkspaceView(document: doc)
                    .modelContainer(ModelContainerManager.shared.container)
                    .environment(\.projectManager, doc.projectManager)
                    .focusedSceneValue(\.activeDocumentID, id)
                    .onDisappear {
                        DocumentRegistry.shared.close(id: id)
                    }
            } else {
                Text("No document available")
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .defaultSize(width: 1000, height: 700)
        .windowToolbarStyle(.unifiedCompact)
    }
}
