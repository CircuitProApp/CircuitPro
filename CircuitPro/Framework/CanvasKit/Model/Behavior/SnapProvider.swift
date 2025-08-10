//
//  SnapProvider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//


import CoreGraphics

/// Defines a contract for an engine that performs application-specific
/// geometric calculations, such as snapping.
protocol SnapProvider {
    /// Snaps an absolute point in the canvas coordinate system.
    func snap(point: CGPoint, context: RenderContext) -> CGPoint
    
    /// Snaps a relative vector (delta).
    func snap(delta: CGVector, context: RenderContext) -> CGVector
}

struct NoOpSnapProvider: SnapProvider {
    func snap(point: CGPoint, context: RenderContext) -> CGPoint {
        return point // Returns the point unmodified
    }
    
    func snap(delta: CGVector, context: RenderContext) -> CGVector {
        return delta // Returns the delta unmodified
    }
}
