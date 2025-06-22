//
//  Pin+Drawable.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/16/25.
//

import AppKit

private let haloThickness: CGFloat = 4      // visual affordance when selected

// ────────────────────────────────────────────────────────────────
// MARK: - Drawable
// ────────────────────────────────────────────────────────────────
extension Pin: Drawable {

    func draw(in ctx: CGContext, selected: Bool) {

        // 1. draw leg & pad
        primitives.forEach { $0.draw(in: ctx, selected: false) }

        // 2. optional halo
        guard selected else { return }

        let haloPath = CGMutablePath()
        for prim in primitives {
            haloPath.addPath(
                prim.makePath()                       // local path
                    .copy(                           // fatten
                        strokingWithWidth: haloThickness,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 10
                    )
            )
        }

        ctx.saveGState()
        ctx.addPath(haloPath)
        ctx.setFillColor(NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 0.4).cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// ────────────────────────────────────────────────────────────────
// MARK: - Hittable
// ────────────────────────────────────────────────────────────────
extension Pin: Tappable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }
}
