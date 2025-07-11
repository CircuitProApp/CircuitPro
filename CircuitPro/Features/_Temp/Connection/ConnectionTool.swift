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
        // If the tool is idle, this tap starts a new drawing session.
        if case .idle = state {
            let newGraph = ConnectionGraph()
            let startVertex = newGraph.addVertex(at: loc)
            self.state = .drawing(graph: newGraph, lastVertexID: startVertex.id)
            return nil // Don't return an element yet.
        }

        // If we are already drawing, this tap adds a segment or finishes the connection.
        guard case .drawing(let graph, let lastVertexID) = state,
              let lastVertex = graph.vertices[lastVertexID] else {
            self.state = .idle
            return nil
        }

        // Always add the next segment to the in-progress graph, capturing the new vertex for tap-ignore.
        let newLastVertexID = addOrthogonalSegment(to: graph, from: lastVertex.point, to: loc)

        // Determine whether to finalize:
        // - Double-tap on empty space.
        // - Tapping an existing connection element (external hit).
        // - Hitting an existing edge or vertex in the in-progress graph (excluding the new vertex).
        let emptyHit = context.hitTarget.map { if case .emptySpace = $0 { return true } else { return false } } ?? true
        let isDoubleTapEmpty = (context.clickCount > 1 && emptyHit)
        let isExternalHit = context.hitTarget.map { if case .emptySpace = $0 { return false } else { return true } } ?? false

        let selfHit = graph.hitTest(at: loc, tolerance: 5.0 / context.magnification)
        let isSelfExistingEdge: Bool
        let isSelfExistingVertex: Bool
        switch selfHit {
        case .edge:
            isSelfExistingEdge = true
            isSelfExistingVertex = false
        case .vertex(let id):
            isSelfExistingVertex = (id != newLastVertexID)
            isSelfExistingEdge = false
        case .emptySpace:
            isSelfExistingEdge = false
            isSelfExistingVertex = false
        }

        if isDoubleTapEmpty || isExternalHit || isSelfExistingEdge || isSelfExistingVertex {
            // Finalize the connection.
            if isSelfExistingEdge, case .edge(let edgeID, let point) = selfHit {
                graph.splitEdge(edgeID, at: point)
            } else if isExternalHit, let hit = context.hitTarget {
                switch hit {
                case .edge(let edgeID, _, let point):
                    graph.splitEdge(edgeID, at: point)
                default:
                    break
                }
            }
            graph.simplifyCollinearSegments()
            let finalElement = ConnectionElement(graph: graph)
            state = .idle
            return .connection(finalElement)
        }

        // Continue drawing: update the last vertex to the one we just added.
        state = .drawing(graph: graph, lastVertexID: newLastVertexID)
        return nil
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
        _ = addOrthogonalSegment(to: previewGraph, from: lastVertex.point, to: mouse)
        
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
    private func addOrthogonalSegment(to graph: ConnectionGraph, from p1: CGPoint, to p2: CGPoint) -> ConnectionVertex.ID {
        let startVertex = graph.ensureVertex(at: p1)
        let lastSegmentOrientation = graph.lastSegmentOrientation(before: startVertex.id)
        
        let startsWithHorizontal = (lastSegmentOrientation == .vertical || lastSegmentOrientation == nil)
        
        let cornerPoint = startsWithHorizontal ? CGPoint(x: p2.x, y: p1.y) : CGPoint(x: p1.x, y: p2.y)
        
        if cornerPoint != p1 {
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: startVertex.id, to: cornerVertex.id)
        }
        
        var endVertex: ConnectionVertex
        if cornerPoint != p2 {
            endVertex = graph.ensureVertex(at: p2)
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: cornerVertex.id, to: endVertex.id)
        } else {
            endVertex = graph.ensureVertex(at: p2)
        }
        return endVertex.id
    }
}

enum ConnectionToolState {
    case idle
    case drawing(graph: ConnectionGraph, lastVertexID: UUID)
}
