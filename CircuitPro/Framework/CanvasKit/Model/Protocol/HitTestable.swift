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
    /// Higher priority wins when multiple items overlap.
    var hitTestPriority: Int { get }
}

extension HitTestable {
    var hitTestPriority: Int { 0 }
}
