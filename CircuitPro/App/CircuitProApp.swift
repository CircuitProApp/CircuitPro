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

@main
struct CircuitProApp: App {

    @Environment(\.openWindow)
    private var openWindow
    


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
                    Task {
                        CircuitProjectDocumentController.shared.openDocument(at: url, onCompletion: { dismiss() })
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
    }
}
