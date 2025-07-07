//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive:
    Transformable & Drawable & Hittable & Bounded & HandleEditable & Codable & Hashable & Identifiable {

    var id: UUID { get }
    var color: SDColor { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }

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

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        let path = makePath()
        if filled { return path.contains(point) }

        let stroke = path.copy(
            strokingWithWidth: strokeWidth + tolerance,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        return stroke.contains(point)
    }

    var boundingBox: CGRect {
        // 3.1 Base geometry
        var box = makePath().boundingBoxOfPath

        // 3.2 Include stroke thickness when outline only
        if !filled {
            let inset = -strokeWidth / 2
            box = box.insetBy(dx: inset, dy: inset)
        }
        return box
    }
}

extension Drawable where Self: GraphicPrimitive {
    func selectionPath() -> CGPath? { makePath() }
}
