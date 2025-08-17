//
//  LibraryCommands.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI
import SwiftDataPacks

struct LibraryCommands: Commands {
    @PackManager private var packManager
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Component Library") {
                 LibraryPanelManager.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
