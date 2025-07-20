//
//  Drawable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.06.25.
//

import SwiftUI

protocol Drawable {

    /// Paint the normal appearance of the object (no selection effects).
    func drawBody(in ctx: CGContext)

    /// Optional outline that should glow when the object is selected.
    /// Returns `nil` for “no halo”.
    func selectionPath() -> CGPath?
}

private let haloWidth: CGFloat = 4               // visual thickness
private let haloAlpha: CGFloat = 0.30            // transparency

extension Drawable {

    /// Colour used for the outline.  If the drawable is (or contains) a
    /// GraphicPrimitive we reuse its stroke colour, otherwise we fall back to blue
    private var haloColor: CGColor {
        switch self {
        case let prim as any GraphicPrimitive:
            return prim.color.cgColor.copy(alpha: haloAlpha) ??
            NSColor.systemBlue.withAlphaComponent(haloAlpha).cgColor
        default:
            return NSColor.systemBlue.withAlphaComponent(haloAlpha).cgColor
        }
    }

    func draw(in ctx: CGContext, selected: Bool) {

        // 1 ─ halo behind the body
        if selected, let outline = selectionPath() {

            ctx.saveGState()

            ctx.setStrokeColor(haloColor)
            ctx.setLineWidth(haloWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            ctx.addPath(outline)
            ctx.strokePath()

            ctx.restoreGState()
        }

        // 2 ─ normal body
        drawBody(in: ctx)
    }
}
