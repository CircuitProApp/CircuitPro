//
//  ManhattanGrid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

struct ManhattanGrid: GridPolicy {
    let step: CGFloat
    let epsilon: CGFloat
    init(step: CGFloat, epsilon: CGFloat? = nil) {
        self.step = step
        self.epsilon = epsilon ?? step * 0.01
    }
    func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x / step).rounded() * step,
                y: (p.y / step).rounded() * step)
    }
    func isHorizontal(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.y - b.y) < epsilon }
    func isVertical(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < epsilon }
}
