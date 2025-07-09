import SwiftUI
import AppKit

/// Draws a poly-line made of `ConnectionSegment`s.
struct ConnectionTool: CanvasTool, Equatable, Hashable {

    // MARK: – Metadata required by CanvasTool
    let id         = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label      = "Connection"

    // MARK: – Internal drawing state
    private var points: [CGPoint] = []     // click history
    private var state: ConnectionToolState = .idle

    private var lastSegmentOrientation: LineOrientation? {
        guard points.count >= 2 else { return nil }
        let p1 = points[points.count - 2]
        let p2 = points.last!
        
        // A segment is considered vertical if the x-coordinates are the same.
        // Otherwise, it's horizontal. This assumes segments are always orthogonal.
        if p1.x == p2.x {
            return .vertical
        } else {
            return .horizontal
        }
    }

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {
        switch state {
        case .idle:
            points.append(loc)
            state = .drawing
            return nil

        case .drawing:
            return handleTapInDrawingState(at: loc)

        case .finished:
            // This state should be transient, handleTap should not be called in this state
            // or it means the previous call returned a connection and state was not reset.
            points.removeAll()
            state = .idle
            return nil
        }
    }

    private mutating func handleTapInDrawingState(at loc: CGPoint) -> CanvasElement? {
        guard let firstVertex = points.first, let lastVertex = points.last else {
            // This case should ideally not happen if state is .drawing
            points.removeAll()
            state = .idle
            return nil
        }

        let distanceToLast = hypot(loc.x - lastVertex.x, loc.y - lastVertex.y)
        let distanceToFirst = hypot(loc.x - firstVertex.x, loc.y - firstVertex.y)

        let shouldFinalize = distanceToLast < 5 || distanceToFirst < 5

        if shouldFinalize {
            // If closing a loop, ensure the points array is correctly set up
            if distanceToFirst < 5 {
                if lastVertex != firstVertex {
                    let startsWithHorizontal: Bool
                    if let lastOrientation = self.lastSegmentOrientation {
                        startsWithHorizontal = (lastOrientation == .vertical)
                    } else {
                        startsWithHorizontal = true
                    }

                    let corner = startsWithHorizontal ? CGPoint(x: firstVertex.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: firstVertex.y)

                    if corner != lastVertex {
                        points.append(corner)
                    }
                }
            } else { // Not closing a loop, but finalizing by proximity to last
                // Add L-shape points for the last segment if not already added
                let startsWithHorizontal: Bool
                if let lastOrientation = self.lastSegmentOrientation {
                    startsWithHorizontal = (lastOrientation == .vertical)
                } else {
                    startsWithHorizontal = true
                }

                let corner = startsWithHorizontal ? CGPoint(x: loc.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: loc.y)

                if corner != lastVertex {
                    points.append(corner)
                }
                if loc != corner {
                    points.append(loc)
                }
            }

            // Finalize the graph
            guard points.count >= 2 else {
                points.removeAll()
                state = .idle
                return nil
            }

            // Simplify the points to remove collinear intermediates
            let simplifiedPoints = ConnectionTool.simplifyCollinear(points)

            // Create a ConnectionGraph from the simplified points.
            let graph = ConnectionGraph()
            var createdVertices: [ConnectionVertex] = []
            for p in simplifiedPoints {
                createdVertices.append(graph.addVertex(at: p))
            }

            // Add edges between consecutive vertices
            for i in 0..<(createdVertices.count - 1) {
                graph.addEdge(from: createdVertices[i].id, to: createdVertices[i+1].id)
            }

            // If it's a closed loop, add the final edge from last to first vertex
            if distanceToFirst < 5 && createdVertices.count >= 2 {
                graph.addEdge(from: createdVertices.last!.id, to: createdVertices.first!.id)
            }

            let conn = ConnectionElement(graph: graph)
            points.removeAll()
            state = .idle // Reset state after finishing
            return .connection(conn)

        } else { // Still drawing, not finalizing
            // Apply L-shape logic
            let startsWithHorizontal: Bool
            if let lastOrientation = self.lastSegmentOrientation {
                startsWithHorizontal = (lastOrientation == .vertical)
            } else {
                startsWithHorizontal = true
            }

            let corner = startsWithHorizontal ? CGPoint(x: loc.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: loc.y)

            if corner != lastVertex {
                points.append(corner)
            }
            if loc != corner {
                points.append(loc)
            }
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {

        guard let lastVertex = points.last else { return }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // 1. Draw existing poly-line (solid)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        
        ctx.beginPath()
        ctx.move(to: points[0])
        for p in points.dropFirst() {
            ctx.addLine(to: p)
        }
        ctx.strokePath()
        
        // 2. Draw the preview L-shape (dotted)
        ctx.setLineDash(phase: 0, lengths: [4])
        
        let startsWithHorizontal: Bool
        if let lastOrientation = self.lastSegmentOrientation {
            startsWithHorizontal = (lastOrientation == .vertical)
        } else {
            // First segment always starts horizontal, as requested.
            startsWithHorizontal = true
        }
        
        let corner = startsWithHorizontal ? CGPoint(x: mouse.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: mouse.y)
        
        ctx.beginPath()
        ctx.move(to: lastVertex)
        ctx.addLine(to: corner)
        ctx.addLine(to: mouse)
        ctx.strokePath()
    }

    // MARK: – Keyboard helpers
    mutating func handleEscape() {
        points.removeAll()
        state = .idle // Reset state on escape
    }

    mutating func handleBackspace() {
        _ = points.popLast()
        if points.isEmpty {
            state = .idle // Go back to idle if all points are removed
        }
    }

    // MARK: – Equatable & Hashable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool { lhs.id == rhs.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    // MARK: - Private Helpers
    private static func simplifyCollinear(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var simplified: [CGPoint] = [points[0]] // Start with the first point

        for i in 1..<points.count {
            let p1 = simplified.last! // Last point added to simplified
            let p2 = points[i]        // Current point from original list

            // If we have at least two points in simplified, check for collinearity with the previous segment
            if simplified.count >= 2 {
                let p0 = simplified[simplified.count - 2] // Point before the last in simplified

                // Check for collinearity (assuming orthogonal lines)
                let isCollinear: Bool
                if p0.x == p1.x && p1.x == p2.x { // Vertical line
                    isCollinear = true
                } else if p0.y == p1.y && p1.y == p2.y { // Horizontal line
                    isCollinear = true
                } else {
                    isCollinear = false
                }

                if isCollinear {
                    // If p0, p1, p2 are collinear, replace p1 with p2 (extend the segment)
                    simplified[simplified.count - 1] = p2
                    continue // Skip appending, as p2 replaced p1
                }
            }
            // Not collinear, or not enough points to check collinearity, append p2
            simplified.append(p2)
        }
        return simplified
    }
}

enum ConnectionToolState {
    case idle
    case drawing
    case finished
}
