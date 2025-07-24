//
//  SnapService.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/16/25.
//


import CoreGraphics

/// Stateless helper that turns free-hand values into grid-aligned ones.
struct SnapService {

    var gridSize:  CGFloat
    var isEnabled: Bool
    var origin: CGPoint = .zero

    // snap an absolute point
    func snap(_ p: CGPoint) -> CGPoint {
        guard isEnabled else { return p }
        func roundToGrid(_ v: CGFloat, offset: CGFloat) -> CGFloat {
            ((v - offset) / gridSize).rounded() * gridSize + offset
        }
        return CGPoint(x: roundToGrid(p.x, offset: origin.x), y: roundToGrid(p.y, offset: origin.y))
    }

    // snap a delta value (dx or dy)
    func snapDelta(_ v: CGFloat) -> CGFloat {
        guard isEnabled else { return v }
        return (v / gridSize).rounded() * gridSize
    }
}
