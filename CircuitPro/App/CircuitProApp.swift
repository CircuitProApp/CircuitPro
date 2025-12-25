//
//  CircuitProApp.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 4/01/25.
//

import SwiftUI
import SwiftDataPacks

@main
struct CircuitProApp: App {

    @State private var packManager: SwiftDataPackManager

     init() {
         let manager = try! SwiftDataPackManager(for: [
             ComponentDefinition.self,
             SymbolDefinition.self,
             FootprintDefinition.self
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
                WorkspaceView()
                    .packContainer(packManager)
                    .environment(\.projectManager, ProjectManager(document: doc))
                    .focusedSceneValue(\.activeDocumentID, id)
                    .onReceive(doc.objectWillChange) { _ in
                        doc.scheduleAutosave()
                    }
                    .onDisappear { DocumentRegistry.shared.close(id: id) }
            }
        }
        .defaultSize(width: 1340, height: 800)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .packContainer(packManager)
        }

        Window("Settings", id: "SettingsWindow") {
            SettingsView()
                .frame(minWidth: 700, minHeight: 500)
        }

        AboutWindowScene()
    }
}
