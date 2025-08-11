//
//  KeyActivatingPanel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//


import AppKit

// A custom NSPanel subclass that can become the key window.
class KeyActivatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        // By returning true, we're telling AppKit that this panel
        // is allowed to receive keyboard focus and become the active window.
        return true
    }
}