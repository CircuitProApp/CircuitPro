//
//  MarqueeView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 14.06.25.
//

import AppKit

final class MarqueeView: NSView {

    // The selection rectangle in *world* coordinates.
    var rect: CGRect? {                    // ← set from the interaction controller
        didSet { needsDisplay = true }
    }

    // Current zoom factor (1 / magnification is used to keep the stroke 1-pixel wide).
    var magnification: CGFloat = 1 {
        didSet { needsDisplay = true }
    }

    // Same coordinate system as the main canvas.
    override var isOpaque: Bool { false }   // overlay must stay transparent

    override func draw(_ dirty: NSRect) {
        guard let rect = rect else { return }

        let scale     = 1 / magnification
        let ctx       = NSGraphicsContext.current!.cgContext

        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
        ctx.setLineWidth(1 * scale)
        ctx.setLineDash(phase: 0, lengths: [4 * scale, 2 * scale])

        ctx.addRect(rect)
        ctx.drawPath(using: .fillStroke)
    }
}
