import SwiftUI
import AppKit

/// Draws a poly-line made of `ConnectionSegment`s.
struct ConnectionTool: CanvasTool, Equatable, Hashable {

    // MARK: – Metadata required by CanvasTool
    let id         = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label      = "Connection"

    // MARK: – Internal drawing state
    private enum Orientation { case horizontal, vertical }
    private var vertices: [CGPoint] = []     // click history
    private var lastSegmentOrientation: Orientation?

    // MARK: – CanvasTool conformance
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {

        guard let lastVertex = vertices.last else {
            vertices.append(loc)
            return nil
        }

        // Finish drawing on a click close to the last vertex.
        let distance = hypot(loc.x - lastVertex.x, loc.y - lastVertex.y)
        if distance < 5 {
            guard vertices.count >= 2 else {
                vertices.removeAll()
                lastSegmentOrientation = nil
                return nil
            }

            let segments = zip(vertices, vertices.dropFirst()).map {
                ConnectionSegment(id: .init(), start: $0, end: $1)
            }
            let conn = ConnectionElement(
                segments: segments,
                position: .zero,
                rotation: 0
            )
            vertices.removeAll()
            lastSegmentOrientation = nil
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
            vertices.append(corner)
        }
        if loc != corner {
            vertices.append(loc)
        }

        // 3. Update state for next time
        let p_before_loc = vertices.count > 1 ? vertices[vertices.count - 2] : lastVertex
        if loc.y == p_before_loc.y {
            self.lastSegmentOrientation = .horizontal
        } else if loc.x == p_before_loc.x {
            self.lastSegmentOrientation = .vertical
        }

        return nil
    }

    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {

        guard let lastVertex = vertices.last else { return }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // 1. Draw existing poly-line (solid)
        ctx.setLineWidth(1)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        
        ctx.beginPath()
        ctx.move(to: vertices[0])
        for p in vertices.dropFirst() {
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
        vertices.removeAll()
        lastSegmentOrientation = nil
    }

    mutating func handleBackspace() {
        _ = vertices.popLast()
        // After popping, we lose the context of the last segment's orientation.
        // Resetting it will force the next segment's orientation to be
        // determined by the mouse direction, which is a reasonable recovery.
        lastSegmentOrientation = nil
    }

    // MARK: – Equatable & Hashable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool { lhs.id == rhs.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}
