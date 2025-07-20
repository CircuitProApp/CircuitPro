//
//  WorkspaceBackgroundView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

final class WorkspaceBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }
}
