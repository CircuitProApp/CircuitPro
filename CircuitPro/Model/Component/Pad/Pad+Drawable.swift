//
//  Pad+Drawable.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import AppKit

private let padHaloThickness: CGFloat = 4

extension Pad: Drawable {

    /// Draws the pad using its geometric primitives and optional halo.
    func draw(in ctx: CGContext, selected: Bool = false) {
        ctx.saveGState()
        // ───────────────────────────────────── 1. unified halo (drawn *behind* the pad)
        if selected {
            let haloPath = CGMutablePath()
            for prim in shapePrimitives {
                let stroked = prim.makePath().copy(
                    strokingWithWidth: padHaloThickness,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 10
                )
                haloPath.addPath(stroked)
            }

            ctx.addPath(haloPath)
            ctx.setFillColor(NSColor(.blue.opacity(0.4)).cgColor)
            ctx.fillPath()
        }

        // ───────────────────────────────────── 2. main shape
        for prim in shapePrimitives {
            prim.draw(in: ctx, selected: false)
        }

        // ───────────────────────────────────── 3. drill hole (clear cutout)
        if type == .throughHole, let drill = drillDiameter {
            let holePath = CGMutablePath()
            holePath.addEllipse(in: CGRect(
                x: position.x - drill / 2,
                y: position.y - drill / 2,
                width: drill,
                height: drill
            ))

            ctx.saveGState()
            ctx.addPath(holePath)
            ctx.setBlendMode(.clear)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }
}
