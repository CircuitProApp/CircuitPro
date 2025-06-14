//
//  MainCommands.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 13/03/2023.
//

import SwiftUI
// import Sparkle

struct MainCommands: Commands {
    @Environment(\.openWindow)
    var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(Bundle.displayName)") {
                openWindow(id: "about")
            }

//            Button("Check for updates...") {
//                NSApp.sendAction(#selector(SPUStandardUpdaterController.checkForUpdates(_:)), to: nil, from: nil)
//            }
        }

//        CommandGroup(replacing: .appSettings) {
//            Button("Settings...") {
//                openWindow(sceneID: .settings)
//            }
//            .keyboardShortcut(",")
//        }
    }
}
