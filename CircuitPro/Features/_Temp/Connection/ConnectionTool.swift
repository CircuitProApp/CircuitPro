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

        // Handle the very first click
        guard let firstVertex = points.first, let lastVertex = points.last else {
            points.append(loc)
            return nil
        }

        // Determine if the user is trying to close a loop or end the line
        let distanceToLast = hypot(loc.x - lastVertex.x, loc.y - lastVertex.y)
        let distanceToFirst = hypot(loc.x - firstVertex.x, loc.y - firstVertex.y)

        let shouldFinalize = distanceToLast < 5 || distanceToFirst < 5

        // If closing a loop, ensure the points array is correctly set up
        if distanceToFirst < 5 {
            // If the current click is near the first point, and the last point
            // is not already the first point, we need to add the first point
            // to the sequence to close the loop.
            if lastVertex != firstVertex {
                // We need to ensure the L-shape logic is applied to reach the firstVertex
                // from the lastVertex, if necessary.
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
                // points.append(firstVertex) // REMOVED: Explicitly add the first vertex to close the loop
            }
        } else if distanceToLast >= 5 { // Only add L-shape points if not finalizing by proximity to last/first
            // 1. Decide next L-shape orientation
            let startsWithHorizontal: Bool
            if let lastOrientation = self.lastSegmentOrientation {
                startsWithHorizontal = (lastOrientation == .vertical) // Start perpendicular
            } else {
                // First segment always starts horizontal, as requested.
                startsWithHorizontal = true
            }

            // 2. Add points for L-shape
            let corner = startsWithHorizontal ? CGPoint(x: loc.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: loc.y)

            if corner != lastVertex {
                points.append(corner)
            }
            if loc != corner {
                points.append(loc)
            }
        }

        // Finalize the graph if the conditions are met
        if shouldFinalize {
            guard points.count >= 2 else {
                points.removeAll()
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
            // This is now handled by ensuring the firstVertex is appended to points
            // if closing a loop, so the last segment in simplifiedPoints will connect
            // back to the first.
            if distanceToFirst < 5 && createdVertices.count >= 2 {
                // Ensure the last point in the simplified sequence is indeed the first point
                // This handles cases where simplifyCollinear might have removed the last point
                // if it was collinear with the second to last and the first.
                // We explicitly add an edge from the last created vertex to the first created vertex
                // to ensure the loop is closed in the graph.
                graph.addEdge(from: createdVertices.last!.id, to: createdVertices.first!.id)
            }


            let conn = ConnectionElement(graph: graph)
            points.removeAll()
            return .connection(conn)
        }

        return nil
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
    }

    mutating func handleBackspace() {
        _ = points.popLast()
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
