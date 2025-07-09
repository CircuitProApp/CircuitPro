//
//  ConnectionElement.swift
//  CircuitPro
//

import SwiftUI
import AppKit

struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {

    // MARK: – Identity
    let id: UUID

    // MARK: – Geometry
    /// Straight-line wire segments expressed in *local* coordinates.
    var segments: [ConnectionSegment]

    // MARK: – Transformable
    var position: CGPoint
    var rotation: CGFloat         // in radians

    // MARK: – Private
    /// Stable IDs for per-segment selection.
    private let segmentIDs: [UUID]

    // MARK: – Init
    init(
        id: UUID = .init(),
        segments: [ConnectionSegment],
        position: CGPoint = .zero,
        rotation: CGFloat = 0
    ) {
        self.id         = id
        self.segments   = segments
        self.position   = position
        self.rotation   = rotation
        // Preserve the UUID baked into each segment so selection never shifts.
        self.segmentIDs = segments.map(\.id)
    }

    // MARK: – Derived geometry
    var primitives: [AnyPrimitive] {
        zip(segmentIDs, segments).map { segID, seg in
            .line(
                LinePrimitive(
                    id:          segID,
                    start:       seg.start,
                    end:         seg.end,
                    rotation:    0,              // LinePrimitive is drawn in this element’s space;
                                                // we apply the whole element’s transform later.
                    strokeWidth: 1,
                    color:       SDColor(color: .blue)
                )
            )
        }
    }

    /// This element’s local-to-world transform.
    private var currentTransform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }

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

        // Draw junction dots (≥ 3 wires share the same vertex *after* transform)
        let vertexCounts = segments
            .flatMap { [$0.start, $0.end] }
            .reduce(into: [CGPoint: Int]()) { counts, localPoint in
                let worldPoint = localPoint.applying(currentTransform)
                counts[worldPoint, default: 0] += 1
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
