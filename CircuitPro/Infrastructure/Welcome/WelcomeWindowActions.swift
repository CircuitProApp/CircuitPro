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

    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        WelcomeButton(iconName: CircuitProSymbols.Generic.plus, title: "Create New Project...") {
            CircuitProjectDocumentController.shared.createFileDocumentWithDialog(
                configuration:
                        .init(allowedContentTypes: [.circuitProject], defaultFileType: .circuitProject),
                onDialogPresented: { dismiss() }
            )
        }
        .symbolVariant(.square)
        WelcomeButton(iconName: CircuitProSymbols.Generic.folder, title: "Open Existing Project...") {
            CircuitProjectDocumentController.shared.openDocumentWithDialog(
                configuration: .init(allowedContentTypes: [.circuitProject]),
                onDialogPresented: { dismiss() }
            )
        }
        .symbolVariant(.rectangle)
        WelcomeButton(iconName: "books.vertical", title: "Create New Component...") {
            openWindow(id: "ComponentDesignWindow")
        }
    }
}
