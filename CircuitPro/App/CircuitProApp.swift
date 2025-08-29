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
         // Initialize the manager once when the app starts.
         // This will throw a fatalError if it fails, which is appropriate
         // for a critical app service that fails on launch.
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
                WorkspaceView(document: doc)
                    .packContainer(packManager)
                    .environment(\.projectManager, ProjectManager(project: doc.model))
                    .focusedSceneValue(\.activeDocumentID, id)
                    .onReceive(doc.objectWillChange) { _ in
                        doc.scheduleAutosave()
                    }
                    .onDisappear { DocumentRegistry.shared.close(id: id) }
            }
        }
        .defaultSize(width: 1000, height: 700)
        .windowToolbarStyle(.unifiedCompact)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        
        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .frame(minWidth: 800, minHeight: 600)
                .packContainer(packManager)
        }
        
        AboutWindowScene()
    }
}
