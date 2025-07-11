import SwiftUI
import AppKit

/// Draws a poly-line made of `ConnectionSegment`s.
struct ConnectionTool: CanvasTool, Equatable, Hashable {

    // MARK: – Metadata required by CanvasTool
    let id         = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
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

        // Check for self-intersection. A click is considered an intersection if it lands on any
        // existing segment of the poly-line being drawn, excluding the most recent segment.
        var intersectionInfo: (point: CGPoint, segmentIndex: Int)?
        if points.count >= 3 { // Need at least two segments (3 points) to intersect with.
            for i in 0..<(points.count - 2) {
                let start = points[i]
                let end = points[i+1]
                let tolerance: CGFloat = 0.01

                let isVertical = abs(start.x - end.x) < tolerance
                let isHorizontal = abs(start.y - end.y) < tolerance

                if isVertical {
                    if abs(loc.x - start.x) < tolerance && loc.y >= min(start.y, end.y) - tolerance && loc.y <= max(start.y, end.y) + tolerance {
                        intersectionInfo = (point: CGPoint(x: start.x, y: loc.y), segmentIndex: i)
                        break
                    }
                } else if isHorizontal {
                    if abs(loc.y - start.y) < tolerance && loc.x >= min(start.x, end.x) - tolerance && loc.x <= max(start.x, end.x) + tolerance {
                        intersectionInfo = (point: CGPoint(x: loc.x, y: start.y), segmentIndex: i)
                        break
                    }
                }
            }
        }

        let shouldFinalize = distanceToLast < 5 || distanceToFirst < 5 || intersectionInfo != nil

        if shouldFinalize {
            let finalLoc = intersectionInfo?.point ?? loc

            // If closing a loop, ensure the points array is correctly set up
            if distanceToFirst < 5 && intersectionInfo == nil {
                if lastVertex != firstVertex {
                    let startsWithHorizontal: Bool
                    if let lastOrientation = self.lastSegmentOrientation {
                        startsWithHorizontal = (lastOrientation == .vertical)
                    } else {
                        startsWithHorizontal = true
                    }

                    let corner = startsWithHorizontal ? CGPoint(x: firstVertex.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: firstVertex.y)

                    if corner != lastVertex && corner != firstVertex {
                        points.append(corner)
                    }
                }
            } else { // Not closing a loop, or self-intersecting
                let startsWithHorizontal: Bool
                if let lastOrientation = self.lastSegmentOrientation {
                    startsWithHorizontal = (lastOrientation == .vertical)
                } else {
                    startsWithHorizontal = true
                }

                let corner = startsWithHorizontal ? CGPoint(x: finalLoc.x, y: lastVertex.y) : CGPoint(x: lastVertex.x, y: finalLoc.y)

                if corner != lastVertex {
                    points.append(corner)
                }
                if finalLoc != corner {
                    points.append(finalLoc)
                }
            }

            // Finalize the graph
            guard points.count >= 2 else {
                points.removeAll()
                state = .idle
                return nil
            }

            // Create a ConnectionGraph from the points.
            // We do not simplify here, as we need the original indices for intersection logic.
            let graph = ConnectionGraph()
            var createdVertices: [ConnectionVertex] = []
            for p in points {
                // Use ensureVertex to handle cases where points might be at the same location (e.g., closing a loop)
                createdVertices.append(graph.ensureVertex(at: p))
            }

            // Add edges between consecutive vertices
            for i in 0..<(createdVertices.count - 1) {
                if createdVertices[i].id != createdVertices[i+1].id {
                    graph.addEdge(from: createdVertices[i].id, to: createdVertices[i+1].id)
                }
            }

            // If it's a closed loop, add the final edge from last to first vertex
            if distanceToFirst < 5 && createdVertices.count >= 2 {
                let firstV = createdVertices.first!
                let lastV = createdVertices.last!
                if firstV.id != lastV.id {
                    graph.addEdge(from: lastV.id, to: firstV.id)
                }
            }

            // If we detected a self-intersection, we need to split the intersected edge.
            if let info = intersectionInfo {
                let startVertex = createdVertices[info.segmentIndex]
                let endVertex = createdVertices[info.segmentIndex + 1]

                // Find the edge in the graph that corresponds to the intersected segment.
                if let edgeToSplit = graph.edges.values.first(where: {
                    ($0.start == startVertex.id && $0.end == endVertex.id) ||
                    ($0.start == endVertex.id && $0.end == startVertex.id)
                }) {
                    // `splitEdge` will find/create a vertex at the intersection point and connect
                    // the split segments to it. Because we already added the intersection point
                    // to our `points` array, `ensureVertex` inside `splitEdge` will find the
                    // existing vertex, correctly forming the junction.
                    graph.splitEdge(edgeToSplit.id, at: info.point)
                }
            }

            // Now that the topology is correct, simplify the graph to merge any collinear segments.
            graph.simplifyCollinearSegments()

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

    mutating func handleReturn() -> CanvasElement? {
        guard state == .drawing, points.count >= 2 else {
            points.removeAll()
            state = .idle
            return nil
        }

        let graph = ConnectionGraph()
        var createdVertices: [ConnectionVertex] = []
        for p in points {
            createdVertices.append(graph.ensureVertex(at: p))
        }

        for i in 0..<(createdVertices.count - 1) {
            if createdVertices[i].id != createdVertices[i+1].id {
                graph.addEdge(from: createdVertices[i].id, to: createdVertices[i+1].id)
            }
        }

        graph.simplifyCollinearSegments()

        let conn = ConnectionElement(graph: graph)
        points.removeAll()
        state = .idle
        return .connection(conn)
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
