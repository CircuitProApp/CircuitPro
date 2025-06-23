//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive: Transformable & Drawable & Hittable & HandleEditable & Codable & Hashable & Identifiable {

    var id: UUID { get }
    var color: SDColor       { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool         { get set }

    func makePath() -> CGPath
}

extension GraphicPrimitive {



        // body drawing stays exactly like today
    func drawBody(in ctx: CGContext) {
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
    }
    

    func hitTest(_ p: CGPoint, tolerance: CGFloat = 5) -> Bool {
        let path = makePath()
        if filled { return path.contains(p) }

        let stroke = path.copy(strokingWithWidth: strokeWidth + tolerance,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: 10)
        return stroke.contains(p)
    }
}

extension Drawable where Self: GraphicPrimitive {
    func selectionPath() -> CGPath? { makePath() }
}
