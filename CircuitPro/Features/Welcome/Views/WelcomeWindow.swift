//
//  WelcomeWindow.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 13/03/2023.
//

import SwiftUI

struct WelcomeWindow: Scene {

    var body: some Scene {
        Window("Welcome To Circuit Pro", id: SceneID.welcome.rawValue) {
            ContentView()
                .frame(width: 740, height: 432)
                .task {
                    if let window = NSApp.findWindow(.welcome) {
                        window.standardWindowButton(.closeButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.isMovableByWindowBackground = true
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    struct ContentView: View {
        @Environment(\.dismiss)
        var dismiss
        @Environment(\.openWindow)
        var openWindow

        var body: some View {
            WelcomeWindowView { url, opened in
                if let url {
                    CircuitProjectDocumentController.shared.openDocument(withContentsOf: url, display: true) { doc, _, _ in
                        if doc != nil {
                            opened()
                        }
                    }
                } else {
                    dismiss()
                    CircuitProjectDocumentController.shared.openDocument(
                        onCompletion: { _, _ in opened() },
                        onCancel: { openWindow(sceneID: .welcome) }
                    )
                }
            } newDocument: {
                CircuitProjectDocumentController.shared.newDocument(nil)
            } dismissWindow: {
                dismiss()
            }
        }
    }
}
