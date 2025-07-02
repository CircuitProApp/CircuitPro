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
}

extension CanvasElement {
    var transformable: Transformable {
        switch self {
        case .primitive(let p):   return p
        case .pin      (let p):   return p
        case .pad      (let p):   return p
        case .symbol   (let s):   return s
        case .connection(let c):  return c
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

     
            return primitives
                .map { $0.makePath().boundingBoxOfPath }
                .reduce(.null) { $0.union($1) }
        
    }
}
 
extension CanvasElement {
    var drawable: Drawable {
        switch self {
        case .primitive(let p):   return p
        case .pin      (let p):   return p
        case .pad      (let p):   return p
        case .symbol   (let s):   return s
        case .connection(let c):  return c
        }
    }
}

extension CanvasElement: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        switch self {

        case .primitive(let p):
            return p.hitTest(point, tolerance: tolerance)

        case .pin(let p):
            return p.hitTest(point, tolerance: tolerance)   // ← forwards to Pin

        case .pad(let p):
            return p.hitTest(point, tolerance: tolerance)

        case .symbol(let s):
            return s.hitTest(point, tolerance: tolerance)

        case .connection(let c):
            return c.hitTest(point, tolerance: tolerance)
        }
    }
}

extension CanvasElement {
    mutating func moveTo(originalPosition  orig: CGPoint, offset delta: CGPoint) {
        switch self {
        case .primitive(var p):
            p.position = orig + delta; self = .primitive(p)
        case .pin(var p):
            p.position = orig + delta; self = .pin(p)
        case .pad(var p):
            p.position = orig + delta; self = .pad(p)
        case .symbol(var s):
            s.position = orig + delta; self = .symbol(s)
        case .connection(var c):
            c.segments = c.segments.map { seg in
                let start = seg.0 + delta
                let end   = seg.1 + delta
                return (start, end)
            }
            self = .connection(c)
        }
    }
}

extension CanvasElement {
    mutating func setRotation(_ angle: CGFloat) {
        switch self {
        case .primitive(var p):    p.rotation            = angle; self = .primitive(p)
        case .pin       (var p):   p.rotation            = angle; self = .pin(p)
        case .pad       (var p):   p.rotation            = angle; self = .pad(p)
        case .symbol    (var s):   s.rotation   = angle; self = .symbol(s)
        case .connection(var c):
            // connection needs a custom implementation because it has no single
            // rotation property; delegate to a method you put on Connection itself
            c.rotation = angle
            self = .connection(c)
        }
    }
}
