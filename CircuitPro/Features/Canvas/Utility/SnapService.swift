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
        guard isEnabled, gridSize > 0 else { return point }

        // To avoid floating point inaccuracies, we work with grid units.
        func roundToGrid(_ value: CGFloat, offset: CGFloat) -> CGFloat {
            let scaledValue = (value - offset) / gridSize
            // Round to the nearest integer grid line, then scale back.
            return round(scaledValue) * gridSize + offset
        }

        return CGPoint(
            x: roundToGrid(point.x, offset: origin.x),
            y: roundToGrid(point.y, offset: origin.y)
        )
    }

    // snap a delta value (dx or dy)
    func snapDelta(_ value: CGFloat) -> CGFloat {
        guard isEnabled, gridSize > 0 else { return value }
        return round(value / gridSize) * gridSize
    }
}
