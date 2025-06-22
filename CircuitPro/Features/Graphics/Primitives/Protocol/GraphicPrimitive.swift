//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive: Placeable & Drawable & Tappable & HandleEditable & Codable & Hashable & Identifiable {

    var id: UUID { get }
    var color: SDColor       { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool         { get set }

    func makePath() -> CGPath
}

extension GraphicPrimitive {

    func draw(in ctx: CGContext, selected: Bool) {
        let path = makePath()

        if filled {
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(strokeWidth)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()
        }

        if selected {
            let haloWidth = max(strokeWidth * 2, strokeWidth + 3)
            let haloColor = CGColor(red: CGFloat(color.red),
                                    green: CGFloat(color.green),
                                    blue: CGFloat(color.blue),
                                    alpha: 0.4)
            ctx.setStrokeColor(haloColor)
            ctx.setLineWidth(haloWidth)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }

    func hitTest(_ p: CGPoint, tolerance: CGFloat = 5) -> Bool {
        let path = makePath()
        if filled { return path.contains(p) }

        let fat = path.copy(strokingWithWidth: strokeWidth + tolerance,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: 10)
        return fat.contains(p)
    }
}
