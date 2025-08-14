//
//  WelcomeWindowScene.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import WelcomeWindow

struct WelcomeWindowScene: Scene {
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WelcomeWindow(
            actions: { dismiss in
                WelcomeButton(iconName: CircuitProSymbols.Generic.plus, title: "Create New Project...") {
                    CircuitProjectDocumentService.shared.createWithDialog(
                        onDialogPresented: { dismiss() },
                        onCompletion: { id in openWindow(value: id) },
                        onCancel: {}
                    )
                }
                .symbolVariant(.square)

                WelcomeButton(iconName: CircuitProSymbols.Generic.folder, title: "Open Existing Project...") {
                    CircuitProjectDocumentService.shared.openWithDialog(
                        onDialogPresented: { dismiss() },
                        onCompletion: { id in openWindow(value: id) },
                        onCancel: {}
                    )
                }
                .symbolVariant(.rectangle)

                WelcomeButton(iconName: "books.vertical", title: "Create New Component...") {
                    openWindow(id: "ComponentDesignWindow")
                }
            },
            onDrop: { url, dismiss in
                Task { @MainActor in
                    CircuitProjectDocumentService.shared.open(at: url) { id in
                        openWindow(value: id)
                        dismiss()
                    } onCancel: {}
                }
            }
        )
    }
}
