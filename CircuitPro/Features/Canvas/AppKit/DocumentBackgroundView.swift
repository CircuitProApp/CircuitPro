//
//  DocumentBackgroundView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

final class DocumentBackgroundView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
}

