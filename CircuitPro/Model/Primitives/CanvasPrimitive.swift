//
//  CanvasPrimitive.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 21.06.25.
//

import AppKit

protocol CanvasPrimitive: Transformable, Identifiable, Codable, Equatable, Hashable, Layerable {

    var id: UUID { get }
    var layerId: UUID? { get set }
    var color: SDColor? { get set }
    var strokeWidth: CGFloat { get set }
    var filled: Bool { get set }

    func makePath() -> CGPath
}

// MARK: - Drawing Helpers
extension CanvasPrimitive {
    func makeDrawingPrimitives(in context: RenderContext) -> [LayeredDrawingPrimitive] {
        // We crash intentionally to alert the developer that they are using the wrong code path.
        // The renderer should always resolve colors before drawing primitives.
        fatalError("`makeDrawingPrimitives(in:)` should not be called directly on a CanvasPrimitive. The renderer must resolve the color first and call `makeDrawingPrimitives(with: resolvedColor)`.")
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
        let path = makePath()

        // This constant defines the extra width for the halo. A value of 4.0 means the
        // visible halo will extend 2.0 points from the edge of the primitive.
        let haloPadding: CGFloat = 0.5

        if filled {
            // For a filled shape, the halo is an outline created by stroking the shape's path.
            // When the renderer fills this new path, it creates a border around the original shape.
            return path.copy(strokingWithWidth: haloPadding, lineCap: .round, lineJoin: .miter, miterLimit: 10)
        } else {
            // For a stroked shape, the halo must be visibly wider than the shape's own stroke.
            // We create a new path based on the original stroke width plus the halo padding.
            let totalWidth = self.strokeWidth + haloPadding
            return path.copy(strokingWithWidth: totalWidth, lineCap: .round, lineJoin: .miter, miterLimit: 10)
        }
    }

    func haloPath() -> CGPath? {
        makeHaloPath()
    }
}

// MARK: - Other Shared Implementations
extension CanvasPrimitive {

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

        // Instead of constructing a framework-specific hit target, we return
        // the primitive's own unique ID. This serves as the `partIdentifier` for consumers
        // that build the final hit target.
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
