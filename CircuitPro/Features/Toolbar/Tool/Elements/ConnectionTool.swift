//  ConnectionTool.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI
import AppKit          // for key-events (Return key finish)

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id         = "connection"
    let symbolName = AppIcons.line
    let label      = "Connection"

    private var start: CGPoint?
    private var startOnWire = false
    private var segments: [ConnectionSegment] = []

    // MARK: – taps -----------------------------------------------------
    mutating func handleTap(at loc: CGPoint,
                            context: CanvasToolContext) -> CanvasElement? {

        // 1. finish on double-tap
        if let s = start, isDoubleTap(from: s, to: loc) {
            return finishRoute()
        }

        // 2. first tap: remember start point + “on wire?”
        guard let s = start else {
            start       = loc
            startOnWire = context.hitSegmentID != nil
            return nil
        }

        // 3. intermediate tap(s)
        let runs      = orthogonalSegments(from: s, to: loc)
        let endOnWire = context.hitSegmentID != nil

        for (i, run) in runs.enumerated() {
            let isFirst = i == 0
            let isLast  = i == runs.count - 1
            let maySplit = (isFirst && startOnWire) || (isLast && endOnWire)
            addSegment(run, allowSplitting: maySplit)
        }

        // 4. auto-finish when we ended on a wire / pad / pin
        if endOnWire { return finishRoute() }

        // 5. prepare for next leg
        start       = loc
        startOnWire = endOnWire
        return nil
    }

    // MARK: – key presses (Return completes route) --------------------
    mutating func handleKeyDown(_ event: NSEvent,
                                context: CanvasToolContext) -> CanvasElement? {
        if event.keyCode == 36 { return finishRoute() }     // ⏎
        return nil
    }

    // MARK: – finish + merge ------------------------------------------
    private mutating func finishRoute() -> CanvasElement? {
        guard !segments.isEmpty else { clearState(); return nil }

        let newConn = ConnectionElement(id: UUID(),
                                        segments: segments,
                                        position: .zero,
                                        rotation: .zero)

        // after creating the element we must clear local state
        clearState()
        return .connection(newConn)
    }

    //  inside ConnectionTool  -------------------------------------------
    static func merge(_ elem: ConnectionElement,
                      into elements: inout [CanvasElement]) -> ConnectionElement {

    // 1. delegate to ConnectionElement.merge
        ConnectionElement.merge(elem, into: &elements)
    }

    // MARK: – drawing preview (unchanged) -----------------------------
    mutating func drawPreview(in ctx: CGContext,
                              mouse: CGPoint,
                              context: CanvasToolContext) {

        guard let s = start else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [4])

        for seg in segments {
            ctx.move(to: seg.start); ctx.addLine(to: seg.end)
        }
        for seg in orthogonalSegments(from: s, to: mouse) {
            ctx.move(to: seg.start); ctx.addLine(to: seg.end)
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: – helpers -------------------------------------------------
    private mutating func addSegment(_ seg: ConnectionSegment,
                                     allowSplitting: Bool) {

        guard seg.start != seg.end else { return }      // zero-length

        // 1. merge with last when collinear & contiguous
        if var last = segments.last,
           last.end == seg.start,
           (last.isHorizontal && seg.isHorizontal) ||
           (last.isVertical   && seg.isVertical)   {

            last.end = seg.end
            segments[segments.count - 1] = last
        }

        // 2. optional T/X
        if allowSplitting {
            var out: [ConnectionSegment] = []
            for var run in segments {
                if let p = run.intersectionPoint(with: seg) {
                    let (a,b) = run.split(at: p)
                    out.append(a); out.append(b)
                    if p != seg.start && p != seg.end {
                        let (c,d) = seg.split(at: p)
                        out.append(c); out.append(d)
                        segments = out; return
                    }
                } else { out.append(run) }
            }
            segments = out
        }

        // 3. append
        segments.append(seg)
    }

    private func isDoubleTap(from a: CGPoint, to b: CGPoint) -> Bool {
        hypot(a.x - b.x, a.y - b.y) < 5
    }

    private func orthogonalSegments(from a: CGPoint, to b: CGPoint) -> [ConnectionSegment] {
        if a.y == b.y { return [ConnectionSegment(start: a, end: b)] }
        if a.x == b.x { return [ConnectionSegment(start: a, end: b)] }
        let m = CGPoint(x: b.x, y: a.y)
        return [ConnectionSegment(start: a, end: m),
                ConnectionSegment(start: m, end: b)]
    }

    private mutating func clearState() {
        start = nil; startOnWire = false; segments.removeAll()
    }

    // MARK: – conformance --------------------------------------------
    static func == (l: Self, r: Self) -> Bool {
        l.id == r.id && l.start == r.start && l.segments == r.segments
    }
    func hash(into h: inout Hasher) {
        h.combine(id); h.combine(start); h.combine(segments)
    }
}

// MARK: – Connection merging helpers ---------------------------------
