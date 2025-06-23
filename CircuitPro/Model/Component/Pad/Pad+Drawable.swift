//
//  Pad+Drawable.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import AppKit

extension Pad: Drawable {

    // ─────────────────────────────────────────────────────────────
    // 1.  Normal appearance
    // ─────────────────────────────────────────────────────────────
    func drawBody(in ctx: CGContext) {

        ctx.saveGState()

        // copper shape – no halo here
        for prim in shapePrimitives {
            prim.drawBody(in: ctx)
        }

        // optional drill hole punched *after* the copper was drawn
        if type == .throughHole, let drill = drillDiameter {
            let holeRect = CGRect(
                x: position.x - drill / 2,
                y: position.y - drill / 2,
                width: drill,
                height: drill
            )
            ctx.addEllipse(in: holeRect)
            ctx.setBlendMode(.clear)          // subtract from what is there
            ctx.fillPath()
            ctx.setBlendMode(.normal)
        }

        ctx.restoreGState()
    }

    // ─────────────────────────────────────────────────────────────
    // 2.  Outline that should glow when the pad is selected
    // ─────────────────────────────────────────────────────────────
    func selectionPath() -> CGPath? {

        let combined = CGMutablePath()
        for prim in shapePrimitives {
            combined.addPath(prim.makePath())
        }

        // The drill hole is *not* part of the halo; leaving it filled
        // results in a nice doughnut-shaped glow for TH pads.
        return combined
    }
}
