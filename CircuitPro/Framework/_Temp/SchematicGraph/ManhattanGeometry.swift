//
//  ManhattanGeometry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import CoreGraphics

struct ManhattanGeometry: GeometryPolicy {
    let step: CGFloat
    let epsilon: CGFloat
    var neighborhoodPadding: CGFloat { step }

    init(step: CGFloat, epsilon: CGFloat? = nil) {
        self.step = step
        self.epsilon = epsilon ?? step * 0.01
    }

    func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: (p.x / step).rounded() * step,
            y: (p.y / step).rounded() * step
        )
    }

    // Axis-aligned unit directions
    func admissibleDirections() -> [CGVector] {
        [CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1)]
    }

    // Collinearity test with tolerance
    func isCollinear(a: CGPoint, b: CGPoint, dir: CGVector) -> Bool {
        let vx = b.x - a.x, vy = b.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        let scale = max(hypot(dir.dx, dir.dy), epsilon)
        return abs(cross) <= epsilon * scale
    }

    // Parametric projection along a direction
    func projectParam(origin: CGPoint, dir: CGVector, point: CGPoint) -> CGFloat {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let denom = max(dir.dx * dir.dx + dir.dy * dir.dy, epsilon * epsilon)
        return (dx * dir.dx + dy * dir.dy) / denom
    }
}
