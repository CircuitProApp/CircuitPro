//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol GraphicPrimitive: Transformable, Drawable, Bounded, HandleEditable, Identifiable, Codable, Equatable, Hashable {

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
            lineJoin: .miter
        )
        return [params]
    }

    /// Provides the path for the default halo implementation in the `Drawable` protocol.
    func makeHaloPath() -> CGPath? {
        return makePath()
    }
}

extension GraphicPrimitive {
    func makeHaloParameters(selectedIDs: Set<UUID>) -> DrawingParameters? {
        guard selectedIDs.contains(self.id) else { return nil }

        guard let path = makeHaloPath(), !path.isEmpty else { return nil }

        let haloColor = self.color.nsColor.withAlphaComponent(0.3).cgColor

        return DrawingParameters(
            path: path,
            lineWidth: 4.0,
            fillColor: nil,
            strokeColor: haloColor
        )
    }
}

// MARK: - Other Shared Implementations
extension GraphicPrimitive {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> AnyHashable? {
        let path = makePath()
        let wasHit: Bool

        // --- LOGGING --- (This part remains the same)
        let shortID = self.id.uuidString.prefix(4)
        // The point is still local to the primitive's own geometry (position = 0,0).
        
        if filled {
            wasHit = path.contains(point)
        } else {
            // Use the stroke width of the primitive plus the interaction tolerance for a more generous hit area.
            let hitTestWidth = (strokeWidth / 2) + tolerance
            let stroke = path.copy(
                strokingWithWidth: hitTestWidth,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            wasHit = stroke.contains(point)
        }
        
        // If the geometry wasn't hit, we return nil as before.
        guard wasHit else { return nil }
        
        // --- THIS IS THE FIX ---
        // Instead of constructing a graphics-specific CanvasHitTarget, we now return
        // the primitive's own unique ID. This serves as the `partIdentifier` for the
        // consuming PrimitiveNode, which will then build the final, generic hit target.
        return self.id
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
