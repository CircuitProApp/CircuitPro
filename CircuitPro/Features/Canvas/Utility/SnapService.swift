//
//  SnapService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//

import CoreGraphics

/// Stateless helper that turns free-hand values into grid-aligned ones.
struct SnapService {

    var gridSize: CGFloat = 10
    var isEnabled: Bool = true
    var origin: CGPoint = .zero

    // snap an absolute point
    func snap(_ value: CGPoint) -> CGPoint {
        // Now it uses the environment it's given for this specific call.
        guard isEnabled, gridSize > 0 else { return value }

        func snapToGrid(_ value: CGFloat) -> CGFloat {
            round(value / gridSize) * gridSize
        }

        return CGPoint(
            x: snapToGrid(value.x),
            y: snapToGrid(value.y)
        )
    }

    // snap a delta value (dx or dy)
    func snapDelta(_ value: CGFloat) -> CGFloat {
        guard isEnabled, gridSize > 0 else { return value }
        return round(value / gridSize) * gridSize
    }
}
