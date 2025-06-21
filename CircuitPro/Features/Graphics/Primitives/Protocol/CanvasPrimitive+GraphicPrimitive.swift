//
//  CanvasPrimitive+GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import SwiftUI

extension CanvasPrimitive where Self: GraphicPrimitive {

    /// Returns `true` when the point falls inside the primitive,
    /// using a fattened stroke when the primitive is not filled.
    func systemHitTest(at point: CGPoint,
                       tolerance: CGFloat = 5) -> Bool
    {
        let path = makePath(offset: .zero)

        if filled {
            return path.contains(point)
        } else {
            let fatStroke = path.copy(strokingWithWidth: strokeWidth + tolerance,
                                      lineCap: .round,
                                      lineJoin: .round,
                                      miterLimit: 10)
            return fatStroke.contains(point)
        }
    }

    /// Renders the primitive on the supplied graphics context.
    /// When `selected` is `true` it paints a translucent halo.
    func draw(in ctx: CGContext, selected: Bool) {

        let path = makePath(offset: .zero)

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
}
