//
//  ConnectionElement.swift
//  CircuitPro
//
//  Updated 02 Jul 2025
//

import SwiftUI
import AppKit

// 1. Segment ----------------------------------------------------------
struct ConnectionSegment: Identifiable, Equatable, Hashable {
    let id = UUID()
    var start: CGPoint
    var end:   CGPoint
}

extension ConnectionSegment {

    // 1.1 orientation
    var isHorizontal: Bool { start.y == end.y }
    var isVertical:   Bool { start.x == end.x }

    // 1.2 intersections / overlaps
    func intersectionPoint(with o: ConnectionSegment) -> CGPoint? {
        if isHorizontal && o.isVertical &&
           o.start.x.isBetween(start.x, end.x) &&
           start.y.isBetween(o.start.y, o.end.y) {
            return CGPoint(x: o.start.x, y: start.y)
        }
        if isVertical && o.isHorizontal &&
           start.x.isBetween(o.start.x, o.end.x) &&
           o.start.y.isBetween(start.y, end.y) {
            return CGPoint(x: start.x, y: o.start.y)
        }
        return nil
    }

    private func range(_ a: CGFloat, _ b: CGFloat) -> ClosedRange<CGFloat> {
        Swift.min(a, b)...Swift.max(a, b)
    }

    func collinearlyTouches(_ o: ConnectionSegment) -> Bool {
        if isHorizontal && o.isHorizontal && start.y == o.start.y {
            return range(start.x, end.x).overlaps(range(o.start.x, o.end.x))
        }
        if isVertical && o.isVertical && start.x == o.start.x {
            return range(start.y, end.y).overlaps(range(o.start.y, o.end.y))
        }
        return false
    }

    func intersects(_ o: ConnectionSegment) -> Bool {
        intersectionPoint(with: o) != nil || collinearlyTouches(o)
    }

    // 1.3 split / merge helpers
    func split(at p: CGPoint) -> (ConnectionSegment, ConnectionSegment) {
        (ConnectionSegment(start: start, end: p),
         ConnectionSegment(start: p,     end: end))
    }

    func splitting(at p: CGPoint) -> [ConnectionSegment] {
        guard p != start, p != end else { return [self] }
        let (a,b) = split(at: p)
        return [a,b]
    }

    func canMerge(with other: ConnectionSegment) -> Bool {
        if isHorizontal && other.isHorizontal && start.y == other.start.y {
            return start.x == other.end.x || end.x == other.start.x
        }
        if isVertical && other.isVertical && start.x == other.start.x {
            return start.y == other.end.y || end.y == other.start.y
        }
        return false
    }

    func merged(with other: ConnectionSegment) -> ConnectionSegment {
        if isHorizontal {
            let xs = [start.x, end.x, other.start.x, other.end.x].sorted()
            return ConnectionSegment(start: CGPoint(x: xs.first!, y: start.y),
                                     end:   CGPoint(x: xs.last!,  y: start.y))
        } else {
            let ys = [start.y, end.y, other.start.y, other.end.y].sorted()
            return ConnectionSegment(start: CGPoint(x: start.x, y: ys.first!),
                                     end:   CGPoint(x: start.x, y: ys.last!))
        }
    }

    // 1.4 normalisation
    static func normalised(_ raw: [ConnectionSegment]) -> [ConnectionSegment] {
        var work = Array(Set(raw))
        var out: [ConnectionSegment] = []
        while let seg = work.popLast() {
            var merged = seg
            var changed = true
            while changed {
                changed = false
                for i in work.indices.reversed() {
                    if merged.canMerge(with: work[i]) {
                        merged = merged.merged(with: work[i])
                        work.remove(at: i)
                        changed = true
                    }
                }
            }
            out.append(merged)
        }
        return out
    }

    static func normalised(_ raw: [ConnectionSegment],
                           endpointCounts: [CGPoint:Int]) -> [ConnectionSegment] {

        var work = Array(Set(raw))
        var out: [ConnectionSegment] = []
        while let seg = work.popLast() {

            var merged = seg
            var changed = true
            while changed {
                changed = false
                for i in work.indices.reversed() {
                    let other = work[i]
                    guard merged.canMerge(with: other) else { continue }

                    let shared = (merged.start == other.start || merged.start == other.end)
                               ? merged.start : merged.end

                    if endpointCounts[shared] == 2 {
                        merged = merged.merged(with: other)
                        work.remove(at: i)
                        changed = true
                    }
                }
            }
            out.append(merged)
        }
        return out
    }
}

// 2. Element -----------------------------------------------------------
struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {

    let id: UUID
    var segments: [ConnectionSegment]

    var position: CGPoint = .zero
    var rotation: CGFloat = 0

    var primitives: [AnyPrimitive] {
        segments.map {
            AnyPrimitive.line(
                LinePrimitive(
                    id: $0.id,
                    start: $0.start,
                    end:   $0.end,
                    rotation: 0,
                    strokeWidth: 1,
                    color: SDColor(color: .blue)
                )
            )
        }
    }

    func drawBody(in ctx: CGContext) {
        primitives.forEach { $0.drawBody(in: ctx) }

        let radius: CGFloat = 3
        ctx.saveGState()
        ctx.setFillColor(NSColor(.blue).cgColor)

        for p in junctionPoints() {
            let r = CGRect(x: p.x - radius, y: p.y - radius,
                           width: radius * 2, height: radius * 2)
            ctx.fillEllipse(in: r)
        }
        ctx.restoreGState()
    }

    func selectionPath() -> CGPath? {
        let path = CGMutablePath()
        primitives.forEach { path.addPath($0.makePath()) }
        return path
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    func hitSegmentID(at p: CGPoint,
                      tolerance: CGFloat = 5) -> UUID? {
        primitives.first { $0.hitTest(p, tolerance: tolerance) }?.id
    }

    // 2.1 junction points
    private func junctionPoints() -> [CGPoint] {

        // 1. count segment end-points
        var endCounts: [CGPoint:Int] = [:]
        for s in segments {
            endCounts[s.start, default: 0] += 1
            endCounts[s.end,   default: 0] += 1
        }

        // 2. collect every true intersection (T- or X-junction)
        var crossings = Set<CGPoint>()
        for i in 0..<segments.count {
            for j in (i + 1)..<segments.count {
                if let p = segments[i].intersectionPoint(with: segments[j]) {
                    crossings.insert(p)
                }
            }
        }

        // 3. any place where ≥3 ends meet  OR  any orthogonal crossing
        let multiEnds = endCounts
            .filter { $0.value >= 3 }
            .map(\.key)

        return Array(crossings.union(multiEnds))
    }

    // 2.2 connectivity
    func isTopologicallyConnected(to other: ConnectionElement) -> Bool {
        for a in segments {
            for b in other.segments where a.intersects(b) { return true }
        }
        return false
    }

    // 2.3 merge (used by tool)
    static func merge(_ elem: ConnectionElement,
                      into elements: inout [CanvasElement]) -> ConnectionElement {

        var pool = elem.segments
        var i = 0
        while i < elements.count {
            if case .connection(let c) = elements[i],
               elem.isTopologicallyConnected(to: c) {
                pool.append(contentsOf: c.segments)
                elements.remove(at: i)
            } else { i += 1 }
        }

        var split: [ConnectionSegment:[CGPoint]] = [:]
        for m in 0..<pool.count {
            for n in (m + 1)..<pool.count {
                if let p = pool[m].intersectionPoint(with: pool[n]) {
                    split[pool[m], default: []].append(p)
                    split[pool[n], default: []].append(p)
                }
            }
        }

        var exploded: [ConnectionSegment] = []
        for seg in pool {
            guard let pts = split[seg], !pts.isEmpty else {
                exploded.append(seg); continue
            }

            let ordered = seg.isHorizontal
            ? (pts + [seg.start, seg.end]).sorted { $0.x < $1.x }
            : (pts + [seg.start, seg.end]).sorted { $0.y < $1.y }

            for k in 0..<(ordered.count - 1) {
                let a = ordered[k], b = ordered[k + 1]
                if a != b { exploded.append(ConnectionSegment(start: a, end: b)) }
            }
        }

        var degree: [CGPoint:Int] = [:]
        for s in exploded {
            degree[s.start, default: 0] += 1
            degree[s.end,   default: 0] += 1
        }

        let cleaned = ConnectionSegment.normalised(exploded,
                                                   endpointCounts: degree)

        return ConnectionElement(id: UUID(),
                                 segments: cleaned,
                                 position: .zero,
                                 rotation: .zero)
    }
}

// 3. Hashing -----------------------------------------------------------
extension ConnectionElement: Hashable {
    func hash(into h: inout Hasher) { h.combine(id) }
}

// 4. CGFloat helper ----------------------------------------------------
extension CGFloat {
    func isBetween(_ a: CGFloat, _ b: CGFloat) -> Bool {
        let lo = Swift.min(a, b), hi = Swift.max(a, b)
        return (lo...hi).contains(self)
    }
}
