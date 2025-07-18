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
                // Should not happen, but as a safeguard, reset the tool.
                state = .idle
                return .noResult
            }

            // Don't add a segment if the click is at the same location.
            if lastVertex.point == loc { return .noResult }

            // Create the next vertex and connect it to the previous one.
            let newVertex = graph.addVertex(at: loc)
            addOrthogonalConnection(graph: graph, from: lastVertexID, to: newVertex.id)

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
        // For now, just resets the tool state.
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

    // MARK: - Private Helpers

    /// Creates the necessary edges (and a corner vertex if needed) to form an orthogonal connection between two existing vertices.
    private func addOrthogonalConnection(graph: SchematicGraph, from startID: ConnectionVertex.ID, to endID: ConnectionVertex.ID) {
        guard let startVertex = graph.vertices[startID],
              let endVertex = graph.vertices[endID] else {
            assertionFailure("Cannot connect non-existent vertices.")
            return
        }

        let from = startVertex.point
        let to = endVertex.point

        if from.x == to.x || from.y == to.y {
            graph.addEdge(from: startID, to: endID)
        } else {
            let cornerPoint = CGPoint(x: to.x, y: from.y)
            let cornerVertex = graph.addVertex(at: cornerPoint)
            graph.addEdge(from: startID, to: cornerVertex.id)
            graph.addEdge(from: cornerVertex.id, to: endID)
        }
    }
}