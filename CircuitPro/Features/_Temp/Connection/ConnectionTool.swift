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
                            context: CanvasToolContext) -> CanvasElement? {
        // If the tool is idle (no drawing state), this tap starts a new drawing session.
        guard var currentDrawing = drawingState else {
            let newGraph = ConnectionGraph()
            let startVertex = newGraph.addVertex(at: loc)
            self.drawingState = DrawingState(graph: newGraph, vertexHistory: [startVertex.id])
            return nil // Don't return an element yet.
        }

        // If we are already drawing, check for finalization conditions.
        guard let lastVertex = currentDrawing.graph.vertices[currentDrawing.lastVertexID] else {
            self.drawingState = nil // Reset state
            return nil
        }

        // --- Finalization Logic ---
        let isDoubleTap = context.clickCount > 1

        let externalHitIsEmpty: Bool
        switch context.hitTarget {
        case .some(.emptySpace), .none:
            externalHitIsEmpty = true
        default:
            externalHitIsEmpty = false
        }

        // Finalize on a double-tap, or a single-tap on an existing element.
        // A single-tap in empty space continues drawing.
        let shouldFinalize = isDoubleTap || !externalHitIsEmpty

        if shouldFinalize {
            // --- Finalization Behavior ---
            _ = addOrthogonalSegment(to: currentDrawing.graph, from: lastVertex.point, to: loc)

            // Return the final element.
            let finalElement = ConnectionElement(graph: currentDrawing.graph)
            drawingState = nil
            return .connection(finalElement)
        }

        // --- Continue Drawing Logic ---
        let newVertexIDs = addOrthogonalSegment(to: currentDrawing.graph, from: lastVertex.point, to: loc)
        currentDrawing.vertexHistory.append(contentsOf: newVertexIDs)
        self.drawingState = currentDrawing // Write back the modified state
        return nil
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

    mutating func handleReturn() -> CanvasElement? {
        guard let drawingState = drawingState, !drawingState.graph.edges.isEmpty else {
            self.drawingState = nil
            return nil
        }
        let graph = drawingState.graph
        let finalElement = ConnectionElement(graph: graph)
        self.drawingState = nil
        return .connection(finalElement)
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
