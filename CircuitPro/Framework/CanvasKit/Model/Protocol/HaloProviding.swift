//
//  HaloProviding.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import CoreGraphics

/// Provides a selection halo path in world space.
protocol HaloProviding {
    func haloPath() -> CGPath?
}

extension HaloProviding {
    func haloPath() -> CGPath? { nil }
}
