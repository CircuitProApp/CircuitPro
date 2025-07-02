//
//  ConnectionTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
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
    private var segments: [ConnectionSegment] = []

    // ---------------------------------------------------------------- taps
    mutating func handleTap(at location: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {

        // 3.1 finish on double-tap
        if let s = start, isDoubleTap(from: s, to: location) {
            defer { clearState() }
            return .connection(
                ConnectionElement(
                    id: UUID(),
                    segments: segments,
                    position: .zero,
                    rotation: .zero
                )
            )
        }

        // 3.2 first tap
        guard let s = start else {
            start = location
            return nil
        }

        // 3.3 intermediate tap ⇒ merge runs
        let runs = orthogonalSegments(from: s, to: location)
        for run in runs {
            addSegment(run)
        }
        start = location
        return nil
    }

    private mutating func addSegment(_ seg: ConnectionSegment) {
        guard seg.start != seg.end else { return }  // skip zero-length

        if var last = segments.last {
            let lastIsHorizontal = last.start.y == last.end.y
            let segIsHorizontal     = seg.start.y == seg.end.y
            let lastIsVertical     = last.start.x == last.end.x
            let segIsVertical       = seg.start.x == seg.end.x
            let contiguous = last.end == seg.start

            if contiguous &&
               ((lastIsHorizontal && segIsHorizontal) ||
                (lastIsVertical   && segIsVertical)) {
                last.end = seg.end
                segments[segments.count - 1] = last
                return
            }
        }

        segments.append(seg)
    }
    
    // ---------------------------------------------------------------- preview
    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {

        guard let s = start else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])

        for seg in segments {
            ctx.move(to: seg.start)
            ctx.addLine(to: seg.end)
        }

        for seg in orthogonalSegments(from: s, to: mouse) {
            ctx.move(to: seg.start)
            ctx.addLine(to: seg.end)
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    // ---------------------------------------------------------------- helpers
    private func isDoubleTap(from a: CGPoint, to b: CGPoint) -> Bool {
        hypot(a.x - b.x, a.y - b.y) < 5
    }

    private func orthogonalSegments(from a: CGPoint, to b: CGPoint) -> [ConnectionSegment] {
        let dx = b.x - a.x
        let dy = b.y - a.y

        // purely horizontal
        if dy == 0, dx != 0 {
            return [ ConnectionSegment(id: .init(), start: a, end: b) ]
        }
        // purely vertical
        if dx == 0, dy != 0 {
            return [ ConnectionSegment(id: .init(), start: a, end: b) ]
        }
        // L-shape: horizontal then vertical
        let mid = CGPoint(x: b.x, y: a.y)
        return [
            ConnectionSegment(id: .init(), start: a,   end: mid),
            ConnectionSegment(id: .init(), start: mid, end: b)
        ]
    }


    private mutating func clearState() {
        start = nil
        segments.removeAll()
    }

    // ---------------------------------------------------------------- Equatable
    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id         == rhs.id &&
        lhs.symbolName == rhs.symbolName &&
        lhs.label      == rhs.label &&
        lhs.start      == rhs.start &&
        lhs.segments == rhs.segments
    }

    // ---------------------------------------------------------------- Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(symbolName)
        hasher.combine(label)
        hasher.combine(start)
        for s in segments { hasher.combine(s) }
    }
}
