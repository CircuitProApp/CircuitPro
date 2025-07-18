import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        // The ID of the last vertex in the chain we are drawing.
        case drawing(lastVertexID: ConnectionVertex.ID)
    }

    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }

        // Finish drawing on double-click
        if context.clickCount > 1 {
            if case .drawing = state {
                state = .idle
                return .schematicModified // Finalize the net
            }
            return .noResult
        }

        switch state {
        case .idle:
            // Start a new connection path by creating the first vertex.
            let firstVertex = graph.addVertex(at: loc)
            state = .drawing(lastVertexID: firstVertex.id)

        case .drawing(let lastVertexID):
            guard let lastVertex = graph.vertices[lastVertexID] else {
                state = .idle
                return .noResult
            }

            if lastVertex.point == loc { return .noResult }

            // Create the next vertex and use the graph's authoritative method to connect it.
            let newVertex = graph.addVertex(at: loc)
            graph.connect(from: lastVertexID, to: newVertex.id)

            // Update the state to continue drawing from the new vertex.
            state = .drawing(lastVertexID: newVertex.id)
        }
        return .schematicModified
    }

    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let graph = context.schematicGraph,
              case .drawing(let lastVertexID) = state,
              let lastVertex = graph.vertices[lastVertexID] else {
            return
        }
        let lastPoint = lastVertex.point

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
        // TODO: This should delete the in-progress net from the graph.
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
        // TODO: Implement backspace to remove the last segment.
    }
}
