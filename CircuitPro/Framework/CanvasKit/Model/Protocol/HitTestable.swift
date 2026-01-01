//
//  HitTestable.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics

/// Describes an object that can perform hit testing in world space.
protocol HitTestable {
    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool
}

extension HitTestable where Self: Bounded {
    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        boundingBox.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }
}
