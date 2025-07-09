//  ConnectionElement.swift
//  CircuitPro
//
//  Updated 09 Jul 2025 – compile fixes
//  • Equatable now compares `id` only (removed tuple‑array equality issue)
//  • `selectionPath` uses `.identity` transform instead of `nil`
//
import SwiftUI
import AppKit

struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {

    // MARK: ‑ Identity
    let id: UUID

    // MARK: ‑ Geometry
    /// List of straight‑line wire segments (local coordinate space).
    let connectionPoints: [(CGPoint, CGPoint)]

    // MARK: ‑ Transformable
    var position: CGPoint
    var rotation: CGFloat

    // MARK: ‑ Private
    /// Stable IDs for each wire segment (selection uses these).
    private let segmentIDs: [UUID]

    // MARK: ‑ Init
    init(
        connectionPoints: [(CGPoint, CGPoint)],
        position: CGPoint = .zero,
        rotation: CGFloat = .zero,
        id: UUID = UUID()
    ) {
        self.id = id
        self.connectionPoints = connectionPoints
        self.position = position
        self.rotation = rotation
        self.segmentIDs = connectionPoints.map { _ in UUID() }
    }

    // MARK: ‑ Derived geometry
    var primitives: [AnyPrimitive] {
        zip(segmentIDs, connectionPoints).map { (id, pair) in
            .line(
                LinePrimitive(
                    id: id,
                    start: pair.0.applying(currentTransform),
                    end: pair.1.applying(currentTransform),
                    rotation: 0,
                    strokeWidth: 1,
                    color: SDColor(color: .blue)
                )
            )
        }
    }

    private var currentTransform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }

    // MARK: ‑ Drawable
    func draw(in ctx: CGContext, with selection: Set<UUID>) {
        drawSelection(in: ctx, selection: selection)
        drawBody(in: ctx)
    }

    private func drawSelection(in ctx: CGContext, selection: Set<UUID>) {
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

    func drawBody(in ctx: CGContext) {
        primitives.forEach { $0.drawBody(in: ctx) }

        // Junctions (≥ 3 connections)
        let vertexCounts = connectionPoints
            .flatMap { [$0.0, $0.1] }
            .reduce(into: [CGPoint: Int]()) { counts, point in
                let p = point.applying(currentTransform)
                counts[p, default: 0] += 1
            }
        let d: CGFloat = 6
        ctx.saveGState()
        ctx.setFillColor(NSColor(.blue).cgColor)
        for (p, n) in vertexCounts where n > 2 {
            let r = CGRect(x: p.x - d/2, y: p.y - d/2, width: d, height: d)
            ctx.fillEllipse(in: r)
        }
        ctx.restoreGState()
    }

    // MARK: ‑ Hittable
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    func hitSegmentID(at point: CGPoint, tolerance: CGFloat = 5) -> UUID? {
        primitives.first { $0.hitTest(point, tolerance: tolerance) }?.id
    }

    // MARK: ‑ Selection helpers
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

// MARK: ‑ Hashable & Equatable
extension ConnectionElement: Hashable, Equatable {
    static func == (lhs: ConnectionElement, rhs: ConnectionElement) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
