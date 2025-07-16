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

    // snap an absolute point
    func snap(_ p: CGPoint) -> CGPoint {
        guard isEnabled else { return p }
        func roundToGrid(_ v: CGFloat) -> CGFloat {
            (v / gridSize).rounded() * gridSize
        }
        return CGPoint(x: roundToGrid(p.x), y: roundToGrid(p.y))
    }

    // snap a delta value (dx or dy)
    func snapDelta(_ v: CGFloat) -> CGFloat {
        guard isEnabled else { return v }
        return (v / gridSize).rounded() * gridSize
    }
}