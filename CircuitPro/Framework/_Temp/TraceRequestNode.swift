//
//  TraceTool.swift
//  CircuitPro
//
//  Created by Gemini
//

import SwiftUI
import AppKit

/// A request to create a multi-segment trace path.
final class TraceRequestNode: BaseNode {
    /// An ordered array of points defining the path, e.g., [start, corner, end].
    let points: [CGPoint]
    let width: CGFloat
    let layerId: UUID

    init(points: [CGPoint], width: CGFloat, layerId: UUID) {
        self.points = points; self.width = width; self.layerId = layerId
        super.init()
    }
}

final class TraceTool: CanvasTool {
    override var symbolName: String { "scribble.variable" }
    override var label: String { "Trace" }

    private enum State {
        case idle
        case drawing(lastPoint: CGPoint)
    }
    private var state: State = .idle

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        // --- THIS IS THE FIX ---
        // We must safely unwrap the activeLayerId. A trace cannot be created
        // without a layer. If no layer is active, we do nothing.
        guard let activeLayerId = context.activeLayerId else {
            print("TraceTool Error: No active layer selected.")
            return .noResult
        }
        
        // For now, we'll use a hardcoded width.
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
            
            // This call is now safe because `activeLayerId` is guaranteed to be a non-optional UUID.
            let requestNode = TraceRequestNode(
                points: pathPoints,
                width: traceWidth,
                layerId: activeLayerId
            )
            
            let newLastPoint = pathPoints.last ?? location
            self.state = .drawing(lastPoint: newLastPoint)
            
            return .newNode(requestNode)
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard case .drawing(let lastPoint) = state else { return [] }
        
        // The preview correctly uses the optional activeLayerId, falling back to a default color.
        let color = context.layers.first(where: { $0.id == context.activeLayerId })?.color ?? NSColor.systemBlue.cgColor
        
        let pathPoints = calculateOptimalPath(from: lastPoint, to: mouse)
        
        let path = CGMutablePath()
        guard let firstPoint = pathPoints.first else { return [] }
        path.move(to: firstPoint)
        for i in 1..<pathPoints.count {
            path.addLine(to: pathPoints[i])
        }
        
        return [.stroke(path: path, color: color, lineWidth: 10.0, lineDash: [4, 4])]
    }
    
    private func calculateOptimalPath(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let dx = abs(delta.x)
        let dy = abs(delta.y)
        
        // Use a small epsilon for floating point comparisons
        if dx < 1e-6 || dy < 1e-6 || abs(dx - dy) < 1e-6 {
            return [start, end]
        }
        
        let diagonalLength = min(dx, dy)
        let corner = CGPoint(
            x: start.x + diagonalLength * delta.x.sign(),
            y: start.y + diagonalLength * delta.y.sign()
        )
        
        // Avoid creating a zero-length final segment if the corner is the same as the end point.
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
