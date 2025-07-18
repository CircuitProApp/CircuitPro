import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        case drawing(from: CGPoint)
    }
    
    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }

        switch state {
        case .idle:
            // TODO: Check for hit on a pin and snap `loc` to it.
            state = .drawing(from: loc)
        case .drawing(let from):
            let startVertex = graph.addVertex(at: from)
            let endVertex = graph.addVertex(at: loc)
            graph.addEdge(from: startVertex.id, to: endVertex.id)
            
            // For now, we reset to idle. A more complex tool could continue drawing.
            state = .idle
        }
        return .noResult
    }
    
    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        switch state {
        case .idle:
            // Draw a small crosshair at the mouse position to indicate where a click will register.
            ctx.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
            ctx.setLineWidth(1.0 / context.magnification)
            ctx.addArc(center: mouse, radius: 4.0 / context.magnification, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            ctx.strokePath()
            
        case .drawing(let from):
            // Draw an orthogonal preview line from the start point to the mouse.
            ctx.setStrokeColor(NSColor.systemGreen.cgColor)
            ctx.setLineWidth(1.0 / context.magnification)
            ctx.setLineDash(phase: 0, lengths: [4 / context.magnification, 2 / context.magnification])

            // Orthogonal line: horizontal segment then vertical segment
            let corner = CGPoint(x: mouse.x, y: from.y)
            
            ctx.move(to: from)
            ctx.addLine(to: corner)
            ctx.addLine(to: mouse)
            ctx.strokePath()
        }
    }

    // MARK: - Tool State Management
    mutating func handleEscape() {
        if case .drawing = state {
            state = .idle
        }
    }
    
    mutating func handleReturn() -> CanvasToolResult {
        // For now, Return does nothing special. Could be used to complete a segment.
        return .noResult
    }
    
    mutating func handleBackspace() {
        // For now, Backspace does nothing. Could be used to remove the last segment.
    }
}
