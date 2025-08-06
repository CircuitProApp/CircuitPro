//
//  GridSnapProcessor.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import CoreGraphics

/// An input processor that snaps incoming points to the canvas grid.
struct GridSnapProcessor: InputProcessor {
    func process(point: CGPoint, context: RenderContext) -> CGPoint {
        // All your familiar snapping logic now lives here.
        guard context.environment.configuration.snapping.isEnabled else {
            return point
        }

        let gridSize = context.environment.configuration.grid.spacing.canvasPoints
        guard gridSize > 0 else {
            return point
        }

        return CGPoint(
            x: round(point.x / gridSize) * gridSize,
            y: round(point.y / gridSize) * gridSize
        )
    }
}
