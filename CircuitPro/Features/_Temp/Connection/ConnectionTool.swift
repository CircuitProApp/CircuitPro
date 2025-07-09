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

    private var lastSegmentOrientation: ConnectionSegment.Orientation? {
        guard points.count >= 2 else { return nil }
        let p1 = points[points.count - 2]
        let p2 = points.last!
        return ConnectionSegment(id: .init(), start: p1, end: p2).orientation
    }

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {

        guard let lastVertex = points.last else {
            points.append(loc)
            return nil
        }

        // Finish drawing on a click close to the last vertex.
        let distance = hypot(loc.x - lastVertex.x, loc.y - lastVertex.y)
        if distance < 5 {
            guard points.count >= 2 else {
                points.removeAll()
                return nil
            }

            let segments = zip(points, points.dropFirst()).map {
                ConnectionSegment(id: .init(), start: $0, end: $1)
            }
            let conn = ConnectionElement(
                segments: segments,
                position: .zero,
                rotation: 0
            )
            points.removeAll()
            return .connection(conn)
        }

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
}
