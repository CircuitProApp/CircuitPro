//
//  GraphicPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//
//  This protocol defines the interface for a primitive that can be drawn on the canvas.
//  It combines a pure data primitive from `PrimitiveKit` with canvas-specific properties
//  like position, rotation, color, and stroke width.
//

import AppKit

protocol GraphicPrimitive: Transformable, Drawable, Bounded, HandleEditable, Identifiable, Codable, Equatable, Hashable, Layerable {

    var id: UUID { get }
    var color: SDColor? { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }

    func makePath() -> CGPath
}

// MARK: - Drawable Conformance
extension GraphicPrimitive {
    func makeDrawingPrimitives() -> [DrawingPrimitive] {
        // We crash intentionally to alert the developer that they are using the wrong code path.
        // The renderer should always use `makeDrawingPrimitives(with:)` for this type.
        fatalError("`makeDrawingPrimitives()` should not be called directly on a GraphicPrimitive. The renderer must resolve the color first and call `makeDrawingPrimitives(with: resolvedColor)`.")
    }

    // --- NEW METHOD: This is the correct way to draw a primitive. ---
    /// Generates drawing primitives using an explicitly provided, non-optional color.
    /// The renderer calls this method after it has determined the final color for the primitive.
    ///
    /// - Parameter resolvedColor: The final, non-optional color to be used for drawing.
    /// - Returns: An array of `DrawingPrimitive`s ready for rendering.
    func makeDrawingPrimitives(with resolvedColor: CGColor) -> [DrawingPrimitive] {
        if filled {
            return [.fill(path: makePath(), color: resolvedColor)]
        } else {
            return [.stroke(path: makePath(), color: resolvedColor, lineWidth: strokeWidth)]
        }
    }

    /// The halo path logic remains correct because it only defines a SHAPE, not a color.
    /// The renderer will be responsible for resolving the halo's color and applying it.
    func makeHaloPath() -> CGPath? {
        return makePath()
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
