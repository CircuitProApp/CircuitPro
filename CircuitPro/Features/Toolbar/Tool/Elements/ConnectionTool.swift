//
//  ConnectionTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id         = "connection"
    let symbolName = AppIcons.line
    let label      = "Connection"

    private var start: CGPoint?
    private var segments: [(CGPoint, CGPoint)] = []

    // ----------------------------------------------------------------– taps
    mutating func handleTap(at location: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {

        // 1 ▸ double-tap = finish
        if let s = start, isDoubleTap(from: s, to: location) {
            defer { clearState() }
            return .connection(ConnectionElement(position: .zero, rotation: .zero, id: UUID(), segments: segments))
        }

        // 2 ▸ first tap = begin
        guard let s = start else {
            start = location
            return nil
        }

        // 3 ▸ intermediate tap = add orthogonal run
        segments.append(contentsOf: orthogonalSegments(from: s, to: location))
        start = location
        return nil
    }

    // ----------------------------------------------------------------– preview
    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {

        guard let s = start else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])

        // confirmed segments
        for seg in segments {
            ctx.move(to: seg.0)
            ctx.addLine(to: seg.1)
        }

        // rubber-band segment
        for seg in orthogonalSegments(from: s, to: mouse) {
            ctx.move(to: seg.0)
            ctx.addLine(to: seg.1)
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    // ----------------------------------------------------------------– helpers
    private func isDoubleTap(from a: CGPoint, to b: CGPoint) -> Bool {
        hypot(a.x - b.x, a.y - b.y) < 5          // 5-pt radius ≈ double-tap
    }

    private func orthogonalSegments(from a: CGPoint, to b: CGPoint)
        -> [(CGPoint, CGPoint)] {

        let mid = CGPoint(x: b.x, y: a.y)        // horizontal then vertical
        return [(a, mid), (mid, b)]
    }

    private mutating func clearState() {
        start = nil
        segments.removeAll()
    }

    // ----------------------------------------------------------------– Equatable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id         == rhs.id &&
        lhs.symbolName == rhs.symbolName &&
        lhs.label      == rhs.label &&
        lhs.start      == rhs.start &&
        lhs.segments.elementsEqual(rhs.segments) { $0.0 == $1.0 && $0.1 == $1.1 }
    }

    // ----------------------------------------------------------------– Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(symbolName)
        hasher.combine(label)
        hasher.combine(start)

        // fold each segment into the hash
        for seg in segments {
            hasher.combine(seg.0.x); hasher.combine(seg.0.y)
            hasher.combine(seg.1.x); hasher.combine(seg.1.y)
        }
    }
}
