//
//  CanvasElement.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/15/25.
//  Refactored 17/07/25 – stripped connection-related code.
//

import SwiftUI

enum CanvasElement: Identifiable, Hashable {

    case primitive(AnyPrimitive)
    case pin(Pin)
    case pad(Pad)
    case symbol(SymbolElement)

    // MARK: – ID
    var id: UUID {
        switch self {
        case .primitive(let primitive): return primitive.id
        case .pin(let pin):             return pin.id
        case .pad(let pad):             return pad.id
        case .symbol(let symbol):       return symbol.id
        }
    }

    // MARK: – Convenience
    var primitive: AnyPrimitive? {
        guard case .primitive(let p) = self else { return nil }
        return p
    }

    // MARK: – Primitives
    var primitives: [AnyPrimitive] {
        switch self {
        case .primitive(let p): return [p]
        case .pin(let pin):     return pin.primitives
        case .pad(let pad):     return pad.shapePrimitives + pad.maskPrimitives
        case .symbol(let sym):  return sym.primitives
        }
    }

    // MARK: – Editing helpers
    var isPrimitiveEditable: Bool {
        if case .primitive = self { return true }
        return false
    }

    func handles() -> [Handle] {
        switch self {
        case .symbol:
            return []                 // symbol is rigid
        default:
            return primitives.flatMap { $0.handles() }
        }
    }

    mutating func updateHandle(
        _ kind: Handle.Kind,
        to point: CGPoint,
        opposite: CGPoint?
    ) {
        guard case .primitive = self else { return }

        var updated = primitives
        for i in updated.indices {
            updated[i].updateHandle(kind, to: point, opposite: opposite)
        }
        if updated.count == 1, let prim = updated.first {
            self = .primitive(prim)
        }
    }
}

// MARK: – Transformable
extension CanvasElement {
    /// Returns the transformable entity, if any.
    var transformable: Transformable {
        switch self {
        case .primitive(let p): return p
        case .pin(let pin):     return pin
        case .pad(let pad):     return pad
        case .symbol(let sym):  return sym
        }
    }
}

// MARK: – Flags
extension CanvasElement {
    var isPin: Bool { if case .pin = self { true } else { false } }
    var isPad: Bool { if case .pad = self { true } else { false } }
}

// MARK: – Bounding Box
extension CanvasElement {
    var boundingBox: CGRect {
        switch self {
        case .pin(let pin):    return pin.boundingBox
        case .pad(let pad):    return pad.boundingBox
        case .symbol(let sym): return sym.boundingBox
        default:
            return primitives
                .map(\.boundingBox)
                .reduce(CGRect.null) { $0.union($1) }
        }
    }
}

// MARK: – Drawable
extension CanvasElement {
    var drawable: Drawable {
        switch self {
        case .primitive(let p): return p
        case .pin(let pin):     return pin
        case .pad(let pad):     return pad
        case .symbol(let sym):  return sym
        }
    }
}

// MARK: – Hittable
extension CanvasElement: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        switch self {
        case .primitive(let p): return p.hitTest(point, tolerance: tolerance)
        case .pin(let pin):     return pin.hitTest(point, tolerance: tolerance)
        case .pad(let pad):     return pad.hitTest(point, tolerance: tolerance)
        case .symbol(let sym):  return sym.hitTest(point, tolerance: tolerance)
        }
    }
}

// MARK: – Transform operations
extension CanvasElement {

    mutating func moveTo(originalPosition orig: CGPoint, offset delta: CGPoint) {
        switch self {
        case .primitive(var p):
            p.position = orig + delta; self = .primitive(p)
        case .pin(var pin):
            pin.position = orig + delta; self = .pin(pin)
        case .pad(var pad):
            pad.position = orig + delta; self = .pad(pad)
        case .symbol(var sym):
            sym.position = orig + delta; self = .symbol(sym)
        }
    }

    mutating func setRotation(_ angle: CGFloat) {
        switch self {
        case .primitive(var p): p.rotation = angle; self = .primitive(p)
        case .pin(var pin):     pin.rotation = angle; self = .pin(pin)
        case .pad(var pad):     pad.rotation = angle; self = .pad(pad)
        case .symbol(var sym):  sym.rotation = angle; self = .symbol(sym)
        }
    }
}
