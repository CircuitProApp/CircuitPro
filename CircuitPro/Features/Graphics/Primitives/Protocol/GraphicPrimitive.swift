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

// MARK: - Drawable Conformance
extension Drawable where Self: GraphicPrimitive {
    
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

    func makeHaloParameters() -> DrawingParameters? {
        let haloWidth: CGFloat = 4.0
        
        let haloColor = self.color.cgColor.copy(alpha: 0.3) ?? NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        let path = makePath()
        guard !path.isEmpty else { return nil }
        
        return DrawingParameters(
            path: path,
            lineWidth: haloWidth,
            fillColor: nil,
            strokeColor: haloColor
        )
    }
}

// MARK: - Other Shared Implementations
extension GraphicPrimitive {

    // The old drawBody(in:) method has been REMOVED from here.
    
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
        var box = makePath().boundingBoxOfPath

        if !filled {
            let inset = -strokeWidth / 2
            box = box.insetBy(dx: inset, dy: inset)
        }
        return box
    }
}
