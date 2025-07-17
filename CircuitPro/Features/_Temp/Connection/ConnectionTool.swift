import SwiftUI
import AppKit

/// Draws a poly-line made of `ConnectionSegment`s.
struct ConnectionTool: CanvasTool, Equatable, Hashable {

    // MARK: – Metadata required by CanvasTool
    let id         = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label      = "Connection"

    // MARK: – Internal drawing state
    private struct DrawingState {
        var graph: ConnectionGraph
        var vertexHistory: [UUID] // History of ALL vertices added, in order.
        var lastVertexID: UUID { vertexHistory.last! }
    }
    private var drawingState: DrawingState?
    
    var isIdle: Bool { drawingState == nil }

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasToolResult {
        
        // Determine the precise location for the new vertex.
        // If we hit a pin or an existing vertex, snap to its exact position.
        let tapLocation: CGPoint
        if let hit = context.hitTarget {
            switch hit {
            case .canvasElement(let part):
                if case .pin(_, _, let position) = part {
                    tapLocation = position
                } else {
                    tapLocation = loc
                }
            case .connection(let part):
                if case .vertex(_, _, let position, _) = part {
                    tapLocation = position
                } else {
                    tapLocation = loc
                }
            }
        } else {
            tapLocation = loc
        }

        if var state = drawingState {
            // Subsequent tap: add a segment to the existing graph.
            guard let lastVertex = state.graph.vertices[state.lastVertexID] else {
                drawingState = nil
                return .noResult
            }

            let newVertexIDs = addOrthogonalSegment(
                to: state.graph,
                from: lastVertex.point,
                to: tapLocation,
                givenOrientation: state.graph.lastSegmentOrientation(before: state.lastVertexID)
            )

            if !newVertexIDs.isEmpty {
                state.vertexHistory.append(contentsOf: newVertexIDs)
            }

            drawingState = state
            
            // If the user double-clicks or clicks on a pin, finish the connection.
            if context.clickCount > 1 {
                return handleReturn()
            }
            if case .canvasElement(part: .pin) = context.hitTarget {
                return handleReturn()
            }
            
            return .noResult

        } else {
            // First tap: start a new drawing.
            var newGraph = ConnectionGraph()
            let startVertex = newGraph.addVertex(at: tapLocation)

            drawingState = DrawingState(
                graph: newGraph,
                vertexHistory: [startVertex.id]
            )
            return .noResult
        }
    }

    func drawPreview(in ctx: CGContext,
                     mouse: CGPoint,
                     context: CanvasToolContext) {
        guard let drawingState = drawingState,
              let lastVertex = drawingState.graph.vertices[drawingState.lastVertexID] else { return }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // 1. Draw the existing, committed part of the graph (solid)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.beginPath()
        for edge in drawingState.graph.edges.values {
            guard let start = drawingState.graph.vertices[edge.start]?.point,
                  let end = drawingState.graph.vertices[edge.end]?.point else { continue }
            ctx.move(to: start)
            ctx.addLine(to: end)
        }
        ctx.strokePath()

        // 2. Draw the preview L-shape to the mouse cursor (dotted, gray)
        ctx.setStrokeColor(NSColor(.blue.opacity(0.7)).cgColor)
        ctx.setLineDash(phase: 0, lengths: [4])
        
        let previewGraph = ConnectionGraph()
        // Get the orientation from the *real* graph to ensure the preview is accurate.
        let lastOrientation = drawingState.graph.lastSegmentOrientation(before: drawingState.lastVertexID)
        _ = addOrthogonalSegment(to: previewGraph, from: lastVertex.point, to: mouse, givenOrientation: lastOrientation)
        
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
        drawingState = nil
    }

    mutating func handleBackspace() {
        guard var currentDrawing = drawingState else { return }

        // Can't undo if we only have the starting point.
        guard currentDrawing.vertexHistory.count > 1 else {
            drawingState = nil
            return
        }

        let vertexToRemoveID = currentDrawing.vertexHistory.removeLast()
        currentDrawing.graph.removeVertex(id: vertexToRemoveID)
        
        // If the graph becomes empty, reset.
        if currentDrawing.vertexHistory.isEmpty {
            drawingState = nil
        } else {
            self.drawingState = currentDrawing
        }
    }

    mutating func handleReturn() -> CanvasToolResult {
        guard let state = drawingState else { return .noResult }

        // Don't create an empty connection.
        guard state.graph.edges.count > 0 else {
            drawingState = nil
            return .noResult
        }

        let newConnection = ConnectionElement(graph: state.graph)
        drawingState = nil // Reset for the next connection.
        return .connection(newConnection)
    }

    // MARK: – Equatable & Hashable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool { lhs.id == rhs.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    // MARK: - Private Helpers
    private func addOrthogonalSegment(to graph: ConnectionGraph, from p1: CGPoint, to p2: CGPoint, givenOrientation: LineOrientation? = nil) -> [ConnectionVertex.ID] {
        var newVertexIDs: [UUID] = []
        let startVertex = graph.ensureVertex(at: p1)

        // If start and end points are the same, do nothing.
        if p1 == p2 {
            return []
        }

        let lastSegmentOrientation = givenOrientation ?? graph.lastSegmentOrientation(before: startVertex.id)
        let startsWithHorizontal = (lastSegmentOrientation == .vertical || lastSegmentOrientation == nil)

        let cornerPoint = startsWithHorizontal ? CGPoint(x: p2.x, y: p1.y) : CGPoint(x: p1.x, y: p2.y)

        // First segment: from p1 to cornerPoint
        if cornerPoint != p1 {
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: startVertex.id, to: cornerVertex.id)
            if !newVertexIDs.contains(cornerVertex.id) {
                newVertexIDs.append(cornerVertex.id)
            }
        }

        // Second segment: from cornerPoint to p2
        if cornerPoint != p2 {
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            let endVertex = graph.ensureVertex(at: p2)
            graph.addEdge(from: cornerVertex.id, to: endVertex.id)
            if !newVertexIDs.contains(endVertex.id) {
                newVertexIDs.append(endVertex.id)
            }
        }

        return newVertexIDs
    }
}
