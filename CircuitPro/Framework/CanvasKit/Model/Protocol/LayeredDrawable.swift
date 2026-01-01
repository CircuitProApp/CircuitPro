//
//  LayeredDrawable.swift
//  CircuitPro
//
//  Created by Codex on 12/30/25.
//

import Foundation

/// Draws into layer buckets using the current render context.
protocol LayeredDrawable: Identifiable where ID == UUID {
    func primitivesByLayer(in context: RenderContext) -> [UUID?: [DrawingPrimitive]]
}
