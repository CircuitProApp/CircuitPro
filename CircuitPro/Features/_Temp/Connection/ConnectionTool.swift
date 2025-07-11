import SwiftUI
import AppKit

/// Draws a poly-line made of `ConnectionSegment`s.
struct ConnectionTool: CanvasTool, Equatable, Hashable {

    // MARK: – Metadata required by CanvasTool
    let id         = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label      = "Connection"

    // MARK: – Internal drawing state
    private var state: ConnectionToolState = .idle

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {
        guard let hitTarget = context.hitTarget else {
            self.state = .idle
            return nil
        }

        // If the tool is idle, this tap will start a drawing session.
        if case .idle = state {
            let initialGraph = context.graphToModify ?? ConnectionGraph()
            let startVertex: ConnectionVertex
            
            // If the graph is new, add a vertex. If we're extending an existing
            // graph, find the vertex we should start from.
            if let existingVertex = initialGraph.vertex(at: loc) {
                startVertex = existingVertex
            } else {
                startVertex = initialGraph.addVertex(at: loc)
            }
            
            self.state = .drawing(graph: initialGraph, lastVertexID: startVertex.id)
            return nil // Don't return an element yet.
        }

        // If we are already drawing, this tap adds a segment or finishes the connection.
        guard case .drawing(let graph, let lastVertexID) = state,
              let lastVertex = graph.vertices[lastVertexID] else {
            self.state = .idle
            return nil
        }

        // Add the L-bend from the last point to the current one.
        addOrthogonalSegment(to: graph, from: lastVertex.point, to: loc)

        // Check if this tap finalizes the connection.
        switch hitTarget {
        case .vertex, .edge:
            // If the tap landed on an existing vertex or edge, we finalize.
            // The key is to merge our in-progress graph with the one from the context if it exists.
            let finalGraph: ConnectionGraph
            if let targetGraph = context.graphToModify {
                targetGraph.merge(with: graph)
                finalGraph = targetGraph
            } else {
                finalGraph = graph
            }
            
            finalGraph.simplifyCollinearSegments()
            let finalElement = ConnectionElement(graph: finalGraph)
            self.state = .idle // Reset for the next connection.
            return .connection(finalElement)
            
        case .emptySpace:
            // We clicked in empty space, so we keep drawing.
            // Update the `lastVertexID` to the new end of the line.
            if let newLastVertex = graph.vertex(at: loc) {
                self.state = .drawing(graph: graph, lastVertexID: newLastVertex.id)
            }
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {
        guard case .drawing(let graph, let lastVertexID) = state,
              let lastVertex = graph.vertices[lastVertexID] else { return }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // 1. Draw the existing, committed part of the graph (solid)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.beginPath()
        for edge in graph.edges.values {
            guard let start = graph.vertices[edge.start]?.point,
                  let end = graph.vertices[edge.end]?.point else { continue }
            ctx.move(to: start)
            ctx.addLine(to: end)
        }
        ctx.strokePath()

        // 2. Draw the preview L-shape to the mouse cursor (dotted, gray)
        ctx.setStrokeColor(NSColor(.blue.opacity(0.7)).cgColor)
        ctx.setLineDash(phase: 0, lengths: [4])
        
        let previewGraph = ConnectionGraph()
        addOrthogonalSegment(to: previewGraph, from: lastVertex.point, to: mouse)
        
        ctx.beginPath()
        for edge in previewGraph.edges.values {
            guard let start = previewGraph.vertices[edge.start]?.point,
                  let end = previewGraph.vertices[edge.end]?.point else { continue }
            ctx.move(to: start)
            ctx.addLine(to: end)
        }
        ctx.strokePath()
    }

    // MARK: – Keyboard helpers
    mutating func handleEscape() {
        state = .idle
    }

    mutating func handleBackspace() {
        // This needs a more robust implementation that can track previous states.
        // For now, simply resetting is the safest option.
        state = .idle
    }

    mutating func handleReturn() -> CanvasElement? {
        guard case .drawing(let graph, _) = state, !graph.edges.isEmpty else {
            state = .idle
            return nil
        }
        graph.simplifyCollinearSegments()
        let finalElement = ConnectionElement(graph: graph)
        state = .idle
        return .connection(finalElement)
    }

    // MARK: – Equatable & Hashable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool { lhs.id == rhs.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    // MARK: - Private Helpers
    private func addOrthogonalSegment(to graph: ConnectionGraph, from p1: CGPoint, to p2: CGPoint) {
        let startVertex = graph.ensureVertex(at: p1)
        let lastSegmentOrientation = graph.lastSegmentOrientation(before: startVertex.id)
        
        let startsWithHorizontal = (lastSegmentOrientation == .vertical || lastSegmentOrientation == nil)
        
        let cornerPoint = startsWithHorizontal ? CGPoint(x: p2.x, y: p1.y) : CGPoint(x: p1.x, y: p2.y)
        
        if cornerPoint != p1 {
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: startVertex.id, to: cornerVertex.id)
        }
        
        if cornerPoint != p2 {
            let endVertex = graph.ensureVertex(at: p2)
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: cornerVertex.id, to: endVertex.id)
        }
    }
}

enum ConnectionToolState {
    case idle
    case drawing(graph: ConnectionGraph, lastVertexID: UUID)
}
