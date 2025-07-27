//
//  SnapService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import CoreGraphics

/// Stateless helper that turns free-hand values into grid-aligned ones.
struct SnapService {

    var gridSize: CGFloat
    var isEnabled: Bool
    var origin: CGPoint = .zero

    // snap an absolute point
    func snap(_ point: CGPoint) -> CGPoint {
        guard isEnabled else { return point }

        func roundToGrid(_ value: CGFloat, offset: CGFloat) -> CGFloat {
            ((value - offset) / gridSize).rounded() * gridSize + offset
        }

        return CGPoint(
            x: roundToGrid(point.x, offset: origin.x),
            y: roundToGrid(point.y, offset: origin.y)
        )
    }

    // snap a delta value (dx or dy)
    func snapDelta(_ value: CGFloat) -> CGFloat {
        guard isEnabled else { return value }
        return (value / gridSize).rounded() * gridSize
    }
}
