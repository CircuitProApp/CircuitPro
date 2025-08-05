//
//  PadNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit

/// A scene graph node that represents a `Pad` data model on the canvas.
///
/// This `CanvasElement` wraps a `Pad` struct and is responsible for its drawing
/// and hit-testing logic. It relies on the geometry calculations defined in the
/// `Pad+Geometry` extension to generate its visual representation.
class PadNode: BaseNode {

    // MARK: - Properties

    /// The underlying data model for this node.
    var pad: Pad

    /// Defines the distinct, hittable parts of a PadNode. For a pad, this
    /// is simply its entire body.
    enum Part: Hashable {
        case body
    }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { pad.position }
        set { pad.position = newValue }
    }

    override var rotation: CGFloat {
        get { pad.rotation }
        set { pad.rotation = newValue }
    }

    // MARK: - Initialization

    init(pad: Pad) {
        self.pad = pad
        // Pass the pad's ID to the superclass to ensure the node and the model
        // share a common identity for selection and management.
        super.init(id: pad.id)
    }

    // MARK: - Drawable Conformance (Local Space)

    override func makeBodyParameters() -> [DrawingParameters] {
        // 1. Generate the pad's final composite path in local space.
        let localPath = pad.calculateCompositePath()
        guard !localPath.isEmpty else { return [] }

        // 2. Define the appearance.
        // The color can be made more dynamic later (e.g., based on layer).
        let copperColor = NSColor.systemRed.cgColor

        // 3. Return the drawing parameters. The BaseNode's renderer will handle
        // applying the node's transform to this local-space path.
        return [DrawingParameters(
            path: localPath,
            lineWidth: 0,
            fillColor: copperColor,
            strokeColor: nil
        )]
    }

    override func makeHaloPath() -> CGPath? {
        let haloWidth: CGFloat = 1.0

        // 1. Get the base shape path in local space (rotated, but no drill hole).
        let shapePath = pad.calculateShapePath()
        guard !shapePath.isEmpty else { return nil }

        // 2. Create an enlarged version for the halo effect.
        let thickOutline = shapePath.copy(strokingWithWidth: haloWidth * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        let enlargedShape = thickOutline.union(shapePath)

        // 3. Subtract the drill hole from the halo shape if necessary.
        let localHaloPath: CGPath
        if pad.type == .throughHole, let drillDiameter = pad.drillDiameter, drillDiameter > 0 {
            let drillMaskPath = CGMutablePath()
            let drillRadius = drillDiameter / 2
            let drillRect = CGRect(x: -drillRadius, y: -drillRadius, width: drillDiameter, height: drillDiameter)
            drillMaskPath.addPath(CGPath(ellipseIn: drillRect, transform: nil))
            localHaloPath = enlargedShape.subtracting(drillMaskPath)
        } else {
            localHaloPath = enlargedShape
        }

        return localHaloPath.isEmpty ? nil : localHaloPath
    }

    // MARK: - Hittable Conformance (Local Space)

    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // The 'point' argument is already in this node's local coordinate system.
        
        // 1. Get the composite path for the pad's body.
        let bodyPath = pad.calculateCompositePath()

        // 2. Create a larger, tappable area by stroking the path.
        let hitArea = bodyPath.copy(strokingWithWidth: tolerance * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        
        // 3. Check for a hit within this expanded area.
        if hitArea.contains(point) {
            return CanvasHitTarget(
                node: self,
                partIdentifier: Part.body,
                // The hit position is the clicked point, converted back to world space
                // for use by other systems (e.g., tool placement).
                position: self.convert(point, to: nil)
            )
        }
        
        return nil
    }
}
