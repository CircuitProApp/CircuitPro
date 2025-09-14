//
//  TraceTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/15/25.
//

import SwiftUI

final class TraceTool: CanvasTool {
    override var symbolName: String { "scribble.variable" }
    override var label: String { "Trace" }

    private enum State {
        case idle
        case drawing(lastPoint: CGPoint)
    }
    private var state: State = .idle

    // The handleTap function is already correct and does not need to change.
    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        guard let activeLayerId = context.activeLayerId else {
            print("TraceTool Error: No active layer selected.")
            return .noResult
        }
        
        let traceWidth: CGFloat = 10.0
        
        switch self.state {
        case .idle:
            self.state = .drawing(lastPoint: location)
            return .noResult

        case .drawing(let lastPoint):
            if context.clickCount >= 2 && location == lastPoint {
                self.state = .idle
                return .noResult
            }

            let pathPoints = calculateOptimalPath(from: lastPoint, to: location)
            let requestNode = TraceRequestNode(points: pathPoints, width: traceWidth, layerId: activeLayerId)
            let newLastPoint = pathPoints.last ?? location
            self.state = .drawing(lastPoint: newLastPoint)
            
            return .newNode(requestNode)
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard case .drawing(let lastPoint) = state else { return [] }
        
        let color = context.layers.first(where: { $0.id == context.activeLayerId })?.color ?? NSColor.systemBlue.cgColor
        
        let pathPoints = calculateOptimalPath(from: lastPoint, to: mouse)
        
        let path = CGMutablePath()
        guard let firstPoint = pathPoints.first else { return [] }
        path.move(to: firstPoint)
        for i in 1..<pathPoints.count {
            path.addLine(to: pathPoints[i])
        }
        
        // --- THIS IS THE FIX ---
        // We remove the `lineDash` parameter to make the preview a solid line.
        // This provides a much clearer "what you see is what you get" experience.
        return [.stroke(
            path: path,
            color: color,
            lineWidth: 10.0 // Should match the tool's width setting
            // No lineDash parameter here
        )]
    }
    
    private func calculateOptimalPath(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let dx = abs(delta.x)
        let dy = abs(delta.y)
        
        if dx < 1e-6 || dy < 1e-6 || abs(dx - dy) < 1e-6 {
            return [start, end]
        }
        
        let diagonalLength = min(dx, dy)
        let corner = CGPoint(
            x: start.x + diagonalLength * delta.x.sign(),
            y: start.y + diagonalLength * delta.y.sign()
        )
        
        if hypot(corner.x - end.x, corner.y - end.y) < 1e-6 {
            return [start, end]
        }
        
        return [start, corner, end]
    }

    override func handleEscape() -> Bool {
        if case .drawing = state {
            state = .idle
            return true
        }
        return false
    }
}

fileprivate extension CGFloat {
    func sign() -> CGFloat {
        return (self > 0) ? 1 : ((self < 0) ? -1 : 0)
    }
}
