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
extension GraphicPrimitive {
    
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

    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
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

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> CanvasHitTarget? {
        // --- This geometric hit-testing logic is correct and remains unchanged ---
        let path = makePath()
        let wasHit: Bool
        if filled {
            wasHit = path.contains(point)
        } else {
            // For stroked paths, we create a new, wider path that represents the stroke
            // and check if the point is contained within that. This correctly handles tolerance.
            let stroke = path.copy(
                strokingWithWidth: strokeWidth + tolerance,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            wasHit = stroke.contains(point)
        }
        
        // If the geometric check failed, there's no hit.
        guard wasHit else { return nil }
        
        // --- This part is updated to return our new, unified struct ---
        // A primitive is the base case for our hierarchy. When it's hit directly,
        // it reports itself as the hit part and its own owner.
        return CanvasHitTarget(
            // The specific part that was hit is this primitive itself.
            partID: self.id,
            
            // As the base of a potential hierarchy, its ownership path
            // starts with and contains only its own ID.
            ownerPath: [self.id],
            
            // We use the more specific `.primitive` kind from our new enum.
            kind: .primitive,
            
            // Pass along the precise location of the hit.
            position: point
        )
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
