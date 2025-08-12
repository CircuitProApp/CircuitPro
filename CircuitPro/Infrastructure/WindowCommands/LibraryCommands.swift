//
//  LibraryCommands.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

struct LibraryCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Component Library") {
                // This assumes LibraryPanelManager.toggle() is a function you've defined.
                // LibraryPanelManager.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            // The following section will only be compiled into Debug builds.
            #if DEBUG
            Divider()

            Button("Export Populated App Library...") {
                DeveloperTools.exportAndSavePopulatedLibrary()
            }
            #endif
        }
    }
}
