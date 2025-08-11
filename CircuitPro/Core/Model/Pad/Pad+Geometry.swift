//
//  Pad+Geometry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/5/25.
//

import AppKit

extension Pad {

    /// Generates the pad's main shape path (e.g., rectangle or circle) in local space.
    /// The path is rotated according to the pad's `rotation` property but does not include any drill hole.
    /// - Returns: A `CGPath` for the basic shape, centered at the origin.
    func calculateShapePath() -> CGPath {
        let path = CGMutablePath()

        // Create the basic shape centered at the origin.
        switch shape {
        case let .rect(width, height):
            let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
            path.addPath(CGPath(rect: rect, transform: nil))
        case let .circle(radius):
            let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
            path.addPath(CGPath(ellipseIn: rect, transform: nil))
        }
        
        // Apply the pad's rotation to the shape.
        var rotationTransform = CGAffineTransform(rotationAngle: rotation)
        return path.copy(using: &rotationTransform) ?? path
    }

    /// Generates the final, composite path for the pad's body, including any drill holes.
    /// The path is rendered in local space (centered at `CGPoint.zero`).
    /// - Returns: A final `CGPath` for the entire pad, ready for rendering.
    func calculateCompositePath() -> CGPath {
        let shapePath = calculateShapePath()

        // If the pad is not a through-hole type, no drill mask is needed.
        guard type == .throughHole, let drillDiameter, drillDiameter > 0 else {
            return shapePath
        }

        // Create the circular path for the drill mask.
        let drillMaskPath = CGMutablePath()
        let drillRadius = drillDiameter / 2
        let drillRect = CGRect(x: -drillRadius, y: -drillRadius, width: drillDiameter, height: drillDiameter)
        drillMaskPath.addPath(CGPath(ellipseIn: drillRect, transform: nil))
        
        // Subtract the drill mask from the main shape to create the final path.
        return shapePath.subtracting(drillMaskPath)
    }
}
