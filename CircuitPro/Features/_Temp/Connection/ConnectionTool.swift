import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        case drawing(points: [CGPoint])
    }
    
    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }
        
        print(context.hitTarget)

        // Finish drawing on double-click
        if context.clickCount > 1 {
            if case .drawing = state {
                state = .idle
                return .schematicModified
            }
            return .noResult
        }

        switch state {
        case .idle:
            // Start a new connection path
            state = .drawing(points: [loc])
            
        case .drawing(var points):
            guard let lastPoint = points.last else {
                state = .idle // Should not happen, but reset if it does.
                return .noResult
            }
            
            // Don't add a segment if the click is at the same location.
            if lastPoint == loc { return .noResult }

            // Add the new point to our path
            points.append(loc)
            state = .drawing(points: points)

            // Create the vertices and edges in the graph
            addOrthogonalSegment(graph: graph, from: lastPoint, to: loc)
        }
        return .schematicModified
    }
    
    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard case .drawing(let points) = state, let lastPoint = points.last else {
            return
        }

        // Draw an orthogonal preview line from the last point to the mouse.
        ctx.setStrokeColor(NSColor.systemGreen.cgColor)
        ctx.setLineWidth(1.0 / context.magnification)
        ctx.setLineDash(phase: 0, lengths: [4 / context.magnification, 2 / context.magnification])

        let corner = CGPoint(x: mouse.x, y: lastPoint.y)
        
        ctx.move(to: lastPoint)
        ctx.addLine(to: corner)
        ctx.addLine(to: mouse)
        ctx.strokePath()
    }

    // MARK: - Tool State Management
    mutating func handleEscape() {
        if case .drawing = state {
            state = .idle
        }
    }
    
    mutating func handleReturn() -> CanvasToolResult {
        if case .drawing = state {
            state = .idle
            return .schematicModified
        }
        return .noResult
    }
    
    mutating func handleBackspace() {
        // For now, Backspace does nothing. Could be used to remove the last segment.
    }
    
    // MARK: - Private Helpers
    
    /// Creates the necessary vertices and edges to form an orthogonal connection between two points.
    private func addOrthogonalSegment(graph: SchematicGraph, from: CGPoint, to: CGPoint) {
        let startVertex = graph.addVertex(at: from)
        let endVertex = graph.addVertex(at: to)

        if from.x == to.x || from.y == to.y {
            graph.addEdge(from: startVertex.id, to: endVertex.id)
        } else {
            let cornerPoint = CGPoint(x: to.x, y: from.y)
            let cornerVertex = graph.addVertex(at: cornerPoint)
            graph.addEdge(from: startVertex.id, to: cornerVertex.id)
            graph.addEdge(from: cornerVertex.id, to: endVertex.id)
        }
    }
}
