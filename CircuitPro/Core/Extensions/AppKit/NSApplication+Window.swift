//
//  NSApplication+Window.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/8/25.
//

import AppKit

extension NSApplication {
    func closeWindow(_ id: String) {
        windows.first { $0.identifier?.rawValue == id }?.close()
    }

    func closeWindows(_ ids: [String]) {
        ids.forEach { closeWindow($0) }
    }

    func findWindow(_ id: String) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id }
    }

    var openSwiftUIWindowIDs: [String] {
        windows.compactMap { $0.identifier?.rawValue }
    }
}
