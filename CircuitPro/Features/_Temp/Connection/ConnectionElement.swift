//
//  ConnectionElement.swift
//  CircuitPro
//

import SwiftUI
import AppKit

// Note: Transformable conformance has been removed. See comments below.
struct ConnectionElement: Identifiable, Drawable, Hittable {

    // MARK: – Identity
    let id: UUID

    // MARK: - Data Model
    /// The underlying graph representing the connection net.
    /// Using a class for ConnectionGraph allows for reference semantics,
    /// where multiple elements could potentially share and manipulate the same net.
    let graph: ConnectionGraph

    // MARK: – Init
    init(
        id: UUID = .init(),
        graph: ConnectionGraph
    ) {
        self.id = id
        self.graph = graph
    }

    // MARK: – Derived geometry
    
    /// The segments of the connection, derived from the graph model.
    /// These segments are in the world coordinate space.
    var segments: [ConnectionSegment] {
        graph.edges.values.compactMap { edge in
            guard let startVertex = graph.vertices[edge.start],
                  let endVertex = graph.vertices[edge.end] else {
                return nil
            }
            return ConnectionSegment(id: edge.id, start: startVertex.point, end: endVertex.point)
        }
    }
    
    var primitives: [AnyPrimitive] {
        segments.map { seg in
            .line(
                LinePrimitive(
                    id:          seg.id,
                    start:       seg.start,
                    end:         seg.end,
                    rotation:    0,
                    strokeWidth: 1,
                    color:       SDColor(color: .blue)
                )
            )
        }
    }

    /// With the removal of Transformable, the concept of a local-to-world transform
    /// for the entire element is no longer applicable. All geometry in the
    /// ConnectionGraph is stored in world coordinates. This simplifies merging
    /// and manipulation of complex nets, as we no longer need to bake-in transforms.
    /// Individual vertices or segments can still be transformed by directly
    /// manipulating the data in the ConnectionGraph.

    // MARK: – Drawable
    func draw(in ctx: CGContext, with selection: Set<UUID>) {
        drawSelection(in: ctx, selection: selection)
        drawBody(in: ctx)
    }

    private func drawSelection(in ctx: CGContext, selection: Set<UUID>) {
        // 1. Whole-connection selected?
        if selection.contains(id), let outline = selectionPath() {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
            ctx.setLineWidth(4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(outline)
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        // 2. Individual segments selected?
        let selectedPath = CGMutablePath()
        var hasSelection = false
        for primitive in primitives where selection.contains(primitive.id) {
            selectedPath.addPath(primitive.makePath())
            hasSelection = true
        }
        if hasSelection {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
            ctx.setLineWidth(4)
            ctx.setLineCap(.round)
            ctx.addPath(selectedPath)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    internal func drawBody(in ctx: CGContext) {
        // Draw the wires
        primitives.forEach { $0.drawBody(in: ctx) }

        // Draw junction dots (≥ 3 wires share the same vertex)
        // This logic now correctly handles complex junctions because it operates
        // on a unified graph in world coordinates.
        let vertexCounts = segments
            .flatMap { [$0.start, $0.end] }
            .reduce(into: [CGPoint: Int]()) { counts, point in
                counts[point, default: 0] += 1
            }

        ctx.saveGState()
        ctx.setFillColor(NSColor(.blue).cgColor)
        let d: CGFloat = 6
        for (p, n) in vertexCounts where n > 2 {
            let r = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
            ctx.fillEllipse(in: r)
        }
        ctx.restoreGState()
    }

    // MARK: – Hittable
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    func hitSegmentID(at point: CGPoint, tolerance: CGFloat = 5) -> UUID? {
        primitives.first { $0.hitTest(point, tolerance: tolerance) }?.id
    }

    // MARK: – Selection helpers
    func selectionPath() -> CGPath? {
        let path = CGMutablePath()
        primitives.forEach { path.addPath($0.makePath()) }
        return path.copy(
            strokingWithWidth: 1,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            transform: .identity
        )
    }
}

// MARK: – Hashable & Equatable
extension ConnectionElement: Hashable, Equatable {
    static func == (lhs: ConnectionElement, rhs: ConnectionElement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
