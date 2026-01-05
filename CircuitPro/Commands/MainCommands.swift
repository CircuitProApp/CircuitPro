//
//  MainCommands.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 8/12/2025.
//

import SwiftUI

struct MainCommands: Commands {

    @Environment(\.openWindow)
    var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(Bundle.displayName)") {
                openWindow(id: "about")
            }
        }

//        CommandGroup(replacing: .appSettings) {
//            Button("Settings...") {
//                openWindow(sceneID: .settings)
//            }
//            .keyboardShortcut(",")
//        }
    }
}
