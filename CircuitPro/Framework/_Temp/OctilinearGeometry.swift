//
//  OctilinearGeometry.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import CoreGraphics

struct OctilinearGeometry: GeometryPolicy {
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

    /// The key difference: we now allow 8 directions (multiples of 45 degrees).
    func admissibleDirections() -> [CGVector] {
        let norm = 1.0 / sqrt(2.0)
        return [
            CGVector(dx: 1, dy: 0),   // Horizontal
            CGVector(dx: 0, dy: 1),   // Vertical
            CGVector(dx: norm, dy: norm), // 45 degrees
            CGVector(dx: -norm, dy: norm) // 135 degrees
        ]
    }
    
    // The other methods from the protocol are generic enough to work
    // without modification for this geometry.
    func isCollinear(a: CGPoint, b: CGPoint, dir: CGVector) -> Bool {
        let vx = b.x - a.x, vy = b.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        let scale = max(hypot(dir.dx, dir.dy), epsilon)
        return abs(cross) <= epsilon * scale
    }

    func projectParam(origin: CGPoint, dir: CGVector, point: CGPoint) -> CGFloat {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let denom = max(dir.dx * dir.dx + dir.dy * dir.dy, epsilon * epsilon)
        return (dx * dir.dx + dy * dir.dy) / denom
    }
}
