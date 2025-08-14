//
//  AutoClosingEmptyWindow.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI

struct AutoClosingEmptyWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { v.window?.performClose(nil) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
