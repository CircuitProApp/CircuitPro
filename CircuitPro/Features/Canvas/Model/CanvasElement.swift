//
//  CanvasElement.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/15/25.
//

import SwiftUI

enum CanvasElement: Identifiable, Hashable {

    case primitive(AnyPrimitive)
    case pin(Pin)
    case pad(Pad)
    case symbol(SymbolElement)
    case connection(ConnectionElement)

    // ─────────────────────────────────────────────── id
    var id: UUID {
        switch self {
        case .primitive(let p): return p.id
        case .pin      (let p): return p.id
        case .pad      (let p): return p.id
        case .symbol   (let s): return s.id
        case .connection(let c): return c.id
        }
    }

    // ─────────────────────────────────────────────── flattened geometry
    var primitives: [AnyPrimitive] {
        switch self {
        case .primitive(let p): return [p]
        case .pin      (let p): return p.primitives
        case .pad      (let p): return p.shapePrimitives + p.maskPrimitives
        case .symbol   (let s): return s.primitives
        case .connection(let c): return c.primitives
        }
    }

    // ─────────────────────────────────────────────── misc helpers
    var isPrimitiveEditable: Bool {
        switch self {
        case .primitive: return true
        default:         return false
        }
    }

    // ─────────────────────────────────────────────── draw
    func draw(in ctx: CGContext, selected: Bool) {
        switch self {
        case .primitive(let p):
            p.draw(in: ctx, selected: selected)
        case .pin(let p):
            p.draw(in: ctx, selected: selected)
        case .pad(let p):
            p.draw(in: ctx, selected: selected)
        case .symbol(let s):
            s.draw(in: ctx, selected: selected)
        case .connection(let c):
            c.draw(in: ctx, selected: selected)
        }
    }

    // ─────────────────────────────────────────────── hit-test & handles
    func systemHitTest(at point: CGPoint) -> Bool {
        switch self {
        case .symbol(let s):
            return s.hitTest(point)
        default:
            return primitives.contains { $0.hitTest(point) }
        }
    }

    func handles() -> [Handle] {
        switch self {
        case .symbol:
            return []                 // symbol is rigid
        default:
            return primitives.flatMap { $0.handles() }
        }
    }

    // ─────────────────────────────────────────────── edit helpers
    mutating func updateHandle(_ kind: Handle.Kind,
                               to point: CGPoint,
                               opposite: CGPoint?) {
        guard case .primitive = self else { return }

        var updated = primitives
        for i in updated.indices {
            updated[i].updateHandle(kind, to: point, opposite: opposite)
        }
        if updated.count == 1, let p = updated.first {
            self = .primitive(p)
        }
    }

    mutating func translate(by delta: CGPoint) {
        switch self {
        case .primitive(var p):
            p.position.x += delta.x
            p.position.y += delta.y
            self = .primitive(p)

        case .pin(var p):
            p.position.x += delta.x
            p.position.y += delta.y
            self = .pin(p)

        case .pad(var p):
            p.position.x += delta.x
            p.position.y += delta.y
            self = .pad(p)

        case .symbol(var s):
            s.translate(by: delta)
            self = .symbol(s)

        case .connection(var c):
            c.segments = c.segments.map { segment in
                let newStart = CGPoint(x: segment.0.x + delta.x, y: segment.0.y + delta.y)
                let newEnd = CGPoint(x: segment.1.x + delta.x, y: segment.1.y + delta.y)
                return (newStart, newEnd)
            }
            self = .connection(c)
        }
    }
}

// ───────────────────────────────────────────────────────── extra flags
extension CanvasElement {
    var isPin: Bool { if case .pin = self { true } else { false } }
    var isPad: Bool { if case .pad = self { true } else { false } }
}

// ───────────────────────────────────────────────────────── bounding box
extension CanvasElement {
    var boundingBox: CGRect {
        switch self {

        case .symbol(let s):
            return .init(origin: .zero, size: .init(width: 100, height: 100))
        default:
            return primitives
                .map { $0.makePath().boundingBoxOfPath }
                .reduce(.null) { $0.union($1) }
        }
    }
}
 
