//
//  ManhattanGrid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import CoreGraphics

public struct ManhattanGeometry: GeometryPolicy {
    public let step: CGFloat
    public let epsilon: CGFloat
    public var neighborhoodPadding: CGFloat { step }

    public init(step: CGFloat, epsilon: CGFloat? = nil) {
        self.step = step
        self.epsilon = epsilon ?? step * 0.01
    }

    public func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: (p.x / step).rounded() * step,
            y: (p.y / step).rounded() * step
        )
    }

    // Axis-aligned unit directions
    public func admissibleDirections() -> [CGVector] {
        [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1)]
    }

    // Collinearity test with tolerance
    public func isCollinear(a: CGPoint, b: CGPoint, dir: CGVector) -> Bool {
        let vx = b.x - a.x, vy = b.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        let scale = max(hypot(dir.dx, dir.dy), epsilon)
        return abs(cross) <= epsilon * scale
    }

    // Parametric projection along a direction
    public func projectParam(origin: CGPoint, dir: CGVector, point: CGPoint) -> CGFloat {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let denom = max(dir.dx * dir.dx + dir.dy * dir.dy, epsilon * epsilon)
        return (dx * dir.dx + dy * dir.dy) / denom
    }
}
