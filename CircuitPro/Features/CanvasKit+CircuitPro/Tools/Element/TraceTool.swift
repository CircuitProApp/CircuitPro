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

    // This property would be updated by a UI control (e.g., a text field in a toolbar).
    // It is initialized with the application's default value.
    var currentTraceWidthInPoints: CGFloat = CircuitPro.Constants.defaultTraceWidthMM * CircuitPro.Constants.pointsPerMillimeter

    private enum State {
        case idle
        case drawing(lastPoint: CGPoint)
    }
    private var state: State = .idle
//    private let traceEngine: TraceEngine

//    init(traceEngine: TraceEngine) {
//        self.traceEngine = traceEngine
//        super.init()
//    }

    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        guard let activeLayerId = context.activeLayerId else {
            print("TraceTool Error: No active layer selected.")
            return .noResult
        }

        // Use the editable property for the trace width.
        let traceWidth = self.currentTraceWidthInPoints

        switch self.state {
        case .idle:
            self.state = .drawing(lastPoint: location)
            return .noResult

        case .drawing(let lastPoint):
//            if context.clickCount >= 2 && location == lastPoint {
//                self.state = .idle
//                return .noResult
//            }
//
//            let pathPoints = calculateOptimalPath(from: lastPoint, to: location)
//            // Pass the current, potentially user-modified, width to the request node.
//            let newLastPoint = pathPoints.last ?? location
//            self.state = .drawing(lastPoint: newLastPoint)
//
//            Task { @MainActor in
//                traceEngine.addTrace(
//                    path: pathPoints,
//                    width: traceWidth,
//                    layerId: activeLayerId
//                )
//            }
            return .noResult
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

        // The preview should always reflect the current width setting.
        return [.stroke(
            path: path,
            color: color,
            lineWidth: self.currentTraceWidthInPoints
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
