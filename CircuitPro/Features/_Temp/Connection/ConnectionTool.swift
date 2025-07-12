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
        var initialHitTarget: ConnectionHitTarget?
    }
    private var drawingState: DrawingState?
    
    public private(set) var initialHitTargetForMerge: ConnectionHitTarget?
    
    var isIdle: Bool { drawingState == nil }

    mutating func resetMergeTarget() {
        initialHitTargetForMerge = nil
    }

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {
        // If the tool is idle (no drawing state), this tap starts a new drawing session.
        guard var currentDrawing = drawingState else {
            let newGraph = ConnectionGraph()
            let startVertex = newGraph.addVertex(at: loc)
            let hitTarget = context.hitTarget
            self.drawingState = DrawingState(graph: newGraph, vertexHistory: [startVertex.id], initialHitTarget: hitTarget)
            self.initialHitTargetForMerge = hitTarget
            return nil // Don't return an element yet.
        }

        // If we are already drawing, check for finalization conditions.
        guard let lastVertex = currentDrawing.graph.vertices[currentDrawing.lastVertexID] else {
            self.drawingState = nil // Reset state
            self.initialHitTargetForMerge = nil
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

        let selfHit = currentDrawing.graph.hitTest(at: loc, tolerance: 5.0 / context.magnification)
        let selfHitIsEmpty: Bool
        switch selfHit {
        case .emptySpace:
            selfHitIsEmpty = true
        default:
            selfHitIsEmpty = false
        }

        // Finalize on a double-tap, or a single-tap on an existing element or the connection itself.
        // A single-tap in empty space continues drawing.
        let shouldFinalize = isDoubleTap || !externalHitIsEmpty || !selfHitIsEmpty

        if shouldFinalize {
            // --- Finalization Behavior ---
            var drawFinalSegment = true
            if case .vertex(let hitVertexID, _, let type) = selfHit {
                // If we clicked on a corner of the line we're currently drawing,
                // we are just finalizing the shape, not closing a loop.
                if type == .corner && currentDrawing.vertexHistory.contains(hitVertexID) {
                    drawFinalSegment = false
                }
            }

            if drawFinalSegment {
                _ = addOrthogonalSegment(to: currentDrawing.graph, from: lastVertex.point, to: loc)
            }

            // If the final click was on an edge, we need to split that edge to form a T-junction.
            if case .edge(let edgeID, let point, _) = selfHit {
                currentDrawing.graph.splitEdge(edgeID, at: point)
            }

            // Clean up the graph and return the final element.
            currentDrawing.graph.simplifyCollinearSegments()
            let finalElement = ConnectionElement(graph: currentDrawing.graph)
            drawingState = nil
            // Don't reset initialHitTargetForMerge here; the controller needs it.
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
        initialHitTargetForMerge = nil
    }

    mutating func handleBackspace() {
        guard var currentDrawing = drawingState else { return }

        // Can't undo if we only have the starting point.
        guard currentDrawing.vertexHistory.count > 1 else {
            drawingState = nil
            initialHitTargetForMerge = nil
            return
        }

        let vertexToRemoveID = currentDrawing.vertexHistory.removeLast()
        currentDrawing.graph.removeVertex(id: vertexToRemoveID)
        
        // If the graph becomes empty, reset.
        if currentDrawing.vertexHistory.isEmpty {
            drawingState = nil
            initialHitTargetForMerge = nil
        } else {
            self.drawingState = currentDrawing
        }
    }

    mutating func handleReturn() -> CanvasElement? {
        guard let drawingState = drawingState, !drawingState.graph.edges.isEmpty else {
            self.drawingState = nil
            self.initialHitTargetForMerge = nil
            return nil
        }
        let graph = drawingState.graph
        graph.simplifyCollinearSegments()
        let finalElement = ConnectionElement(graph: graph)
        self.drawingState = nil
        // Don't reset initialHitTargetForMerge here; the controller needs it.
        return .connection(finalElement)
    }

    // MARK: – Equatable & Hashable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool { lhs.id == rhs.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    // MARK: - Private Helpers
    private func addOrthogonalSegment(to graph: ConnectionGraph, from p1: CGPoint, to p2: CGPoint, givenOrientation: LineOrientation? = nil) -> [ConnectionVertex.ID] {
        var newVertexIDs: [UUID] = []
        let startVertex = graph.ensureVertex(at: p1)
        
        // Use the given orientation if provided; otherwise, calculate it from the graph.
        // This is crucial for generating an accurate preview.
        let lastSegmentOrientation = givenOrientation ?? graph.lastSegmentOrientation(before: startVertex.id)
        
        let startsWithHorizontal = (lastSegmentOrientation == .vertical || lastSegmentOrientation == nil)
        
        let cornerPoint = startsWithHorizontal ? CGPoint(x: p2.x, y: p1.y) : CGPoint(x: p1.x, y: p2.y)
        
        if cornerPoint != p1 {
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: startVertex.id, to: cornerVertex.id)
            newVertexIDs.append(cornerVertex.id)
        }
        
        if cornerPoint != p2 {
            let endVertex = graph.ensureVertex(at: p2)
            let cornerVertex = graph.ensureVertex(at: cornerPoint)
            graph.addEdge(from: cornerVertex.id, to: endVertex.id)
            newVertexIDs.append(endVertex.id)
        } else {
            // p2 is the corner point.
            let endVertex = graph.ensureVertex(at: p2)
            // If it wasn't added as a corner, add it now.
            if !newVertexIDs.contains(endVertex.id) {
                newVertexIDs.append(endVertex.id)
            }
        }
        
        var uniqueIDs = [UUID]()
        for id in newVertexIDs {
            if !uniqueIDs.contains(id) {
                uniqueIDs.append(id)
            }
        }
        return uniqueIDs
    }
}
