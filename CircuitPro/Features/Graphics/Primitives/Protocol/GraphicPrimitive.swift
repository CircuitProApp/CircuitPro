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

extension Drawable where Self: GraphicPrimitive {
    
    /// Provides the `Drawable` conformance for all graphic primitives.
    func makeBodyParameters() -> [DrawingParameters] {
        let params = DrawingParameters(
            path: makePath(),
            lineWidth: filled ? 0.0 : strokeWidth, // No stroke if filled
            fillColor: filled ? color.cgColor : nil,
            strokeColor: filled ? nil : color.cgColor,
            lineCap: .round,
            lineJoin: .round
        )
        return [params]
    }

    /// For a single primitive, the selection path is simply its own path.
    func selectionPath() -> CGPath? {
        return makePath()
    }
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

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        let path = makePath()
        let wasHit: Bool
        if filled {
            wasHit = path.contains(point)
        } else {
            let stroke = path.copy(
                strokingWithWidth: strokeWidth + tolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            wasHit = stroke.contains(point)
        }
        
        return wasHit ? .canvasElement(part: .body(id: id)) : nil
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
