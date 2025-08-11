//
//  CircuitProSnapProvider.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

class CircuitProSnapProvider: SnapProvider {

    func snap(point: CGPoint, context: RenderContext) -> CGPoint {
        guard context.environment.configuration.snapping.isEnabled else { return point }
        
        let gridSize = context.environment.configuration.grid.spacing.canvasPoints
        guard gridSize > 0 else { return point }

        return CGPoint(
            x: round(point.x / gridSize) * gridSize,
            y: round(point.y / gridSize) * gridSize
        )
    }
    
    func snap(delta: CGVector, context: RenderContext) -> CGVector {
        guard context.environment.configuration.snapping.isEnabled else { return delta }

        let gridSize = context.environment.configuration.grid.spacing.canvasPoints
        guard gridSize > 0 else { return delta }
        
        return CGVector(
            dx: round(delta.dx / gridSize) * gridSize,
            dy: round(delta.dy / gridSize) * gridSize
        )
    }
}
