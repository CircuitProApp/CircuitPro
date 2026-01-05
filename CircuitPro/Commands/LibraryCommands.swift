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
                 LibraryPanelManager.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
