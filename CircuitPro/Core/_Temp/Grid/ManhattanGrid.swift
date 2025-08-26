//
//  ManhattanGrid.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/26/25.
//

import Foundation

public struct ManhattanGrid: GridPolicy {
    public let step: CGFloat
    public let epsilon: CGFloat
    public init(step: CGFloat, epsilon: CGFloat? = nil) {
        self.step = step
        self.epsilon = epsilon ?? step * 0.01
    }
    public func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x / step).rounded() * step,
                y: (p.y / step).rounded() * step)
    }
    public func isHorizontal(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.y - b.y) < epsilon }
    public func isVertical(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < epsilon }
}
