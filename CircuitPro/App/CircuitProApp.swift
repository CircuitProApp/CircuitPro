//
//  CircuitProApp.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 4/01/25.
//

import SwiftDataPacks
import SwiftUI

@main
struct CircuitProApp: App {

    @State private var packManager: SwiftDataPackManager

    init() {
        let manager = try! SwiftDataPackManager(for: [
            ComponentDefinition.self,
            SymbolDefinition.self,
            FootprintDefinition.self,
        ])
        _packManager = State(initialValue: manager)
    }

    var body: some Scene {
        WelcomeWindowScene(packManager: packManager)
            .commands {
                CircuitProCommands()
            }

        WindowGroup(for: DocumentID.self) { $docID in
            if let id = docID, let doc = DocumentRegistry.shared.document(for: id) {
                WorkspaceContainer(document: doc, documentID: id)
                    .packContainer(packManager)
                    .focusedSceneValue(\.activeDocumentID, id)
                    .onReceive(doc.objectWillChange) { _ in
                        doc.scheduleAutosave()
                    }
                    .onDisappear { DocumentRegistry.shared.close(id: id) }
            }
        }
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .packContainer(packManager)
        }

        Window("Connection Sandbox", id: "ConnectionSandboxWindow") {
            ConnectionSandboxView()
                .frame(minWidth: 800, minHeight: 600)
        }

        Window("Settings", id: "SettingsWindow") {
            SettingsView()
                .frame(minWidth: 700, minHeight: 500)
        }

        AboutWindowScene()
    }
}
