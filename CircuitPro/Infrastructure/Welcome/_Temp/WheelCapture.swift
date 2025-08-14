//
//  WheelCapture.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI

struct WheelCapture: NSViewRepresentable {
    var onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat, _ phase: NSEvent.Phase) -> Void

    func makeNSView(context: Context) -> NSView {
        WheelCatcher(onScroll: onScroll)
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class WheelCatcher: NSView {
        let onScroll: (_ dx: CGFloat, _ dy: CGFloat, _ phase: NSEvent.Phase) -> Void
        init(onScroll: @escaping (_ dx: CGFloat, _ dy: CGFloat, _ phase: NSEvent.Phase) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
            self.wantsLayer = true
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
        required init?(coder: NSCoder) { fatalError() }

        override func scrollWheel(with event: NSEvent) {
            // Pass the deltas and the event phase to our handler.
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY, event.phase)
            
            // Pass the event to the superclass to ensure the ScrollView still works when needed.
            super.scrollWheel(with: event)
        }
    }
}
