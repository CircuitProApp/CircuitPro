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
    @AppStorage(AppThemeKeys.appearance) private var appearance = AppAppearance.system.rawValue

    init() {
        let manager = try! SwiftDataPackManager(for: [
            ComponentDefinition.self,
            SymbolDefinition.self,
            FootprintDefinition.self,
        ])
        _packManager = State(initialValue: manager)
    }

    var body: some Scene {
        let preferredScheme = AppAppearance(rawValue: appearance)?.preferredColorScheme

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
                    .preferredColorScheme(preferredScheme)
            }
        }
        .defaultSize(width: 1340, height: 800)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .packContainer(packManager)
                .preferredColorScheme(preferredScheme)
        }

        Window("Settings", id: "SettingsWindow") {
            SettingsView()
                .frame(minWidth: 700, minHeight: 500)
                .preferredColorScheme(preferredScheme)
        }

        AboutWindowScene()
    }
}
