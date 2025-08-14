//
//  WelcomeWindowActions.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import WelcomeWindow

struct WelcomeWindowActions: View {
    var dismiss: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WelcomeButton(iconName: CircuitProSymbols.Generic.plus, title: "Create New Project...") {
            NSDocumentController.shared.createFileDocumentWithDialog(
                configuration: .init(allowedContentTypes: [.circuitProject], defaultFileType: .circuitProject),
                onDialogPresented: { dismiss() },
                onCompletion: { id in
                    openWindow(value: id) // Correct: value-based routing
                },
                onCancel: {}
            )
        }
        .symbolVariant(.square)

        WelcomeButton(iconName: CircuitProSymbols.Generic.folder, title: "Open Existing Project...") {
            NSDocumentController.shared.openDocumentWithDialog(
                configuration: .init(allowedContentTypes: [.circuitProject]),
                onDialogPresented: { dismiss() },
                onCompletion: { id in
                    openWindow(value: id) // Correct: value-based routing
                },
                onCancel: {}
            )
        }
        .symbolVariant(.rectangle)

        WelcomeButton(iconName: "books.vertical", title: "Create New Component...") {
            openWindow(id: "ComponentDesignWindow")
        }
    }
}
