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

    // MARK: ID
    var id: UUID {
        switch self {
        case .primitive(let primitive): return primitive.id
        case .pin(let pin): return pin.id
        case .pad(let pad): return pad.id
        case .symbol(let symbol): return symbol.id
        case .connection(let connection): return connection.id
        }
    }

    var primitive: AnyPrimitive? {
        guard case .primitive(let primitive) = self else { return nil }
        return primitive
    }

    // MARK: Primitives
    var primitives: [AnyPrimitive] {
        switch self {
        case .primitive(let primitive): return [primitive]
        case .pin(let pin): return pin.primitives
        case .pad(let pad): return pad.shapePrimitives + pad.maskPrimitives
        case .symbol(let symbol): return symbol.primitives
        case .connection(let connection): return connection.primitives
        }
    }

    // MARK: Helpers
    var isPrimitiveEditable: Bool {
        switch self {
        case .primitive: return true
        default: return false
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
        if updated.count == 1, let primitive = updated.first {
            self = .primitive(primitive)
        }
    }
}

extension CanvasElement {
    /// Returns the transformable properties of the element, if available.
    /// Note: `ConnectionElement` is not considered transformable as a whole,
    /// as a complex net does not have a single position or rotation.
    /// It can be moved, but this is handled by translating all its vertices.
    var transformable: Transformable? {
        switch self {
        case .primitive(let primitive): return primitive
        case .pin(let pin): return pin
        case .pad(let pad): return pad
        case .symbol(let symbol): return symbol
        case .connection: return nil
        }
    }
}

// MARK: Flags
extension CanvasElement {
    var isPin: Bool { if case .pin = self { true } else { false } }
    var isPad: Bool { if case .pad = self { true } else { false } }
}

// MARK: Bounding Box
extension CanvasElement {
    var boundingBox: CGRect {
        switch self {
        case .pin(let pin): return pin.boundingBox
        case .pad(let pad): return pad.boundingBox
        case .symbol(let symbol): return symbol.boundingBox
        default:
            return primitives
                .map(\.boundingBox)
                .reduce(CGRect.null) { $0.union($1) }
        }
    }
}

extension CanvasElement {
    var drawable: Drawable {
        switch self {
        case .primitive(let primitive): return primitive
        case .pin(let pin): return pin
        case .pad(let pad): return pad
        case .symbol(let symbol): return symbol
        case .connection(let connection): return connection
        }
    }
}

extension CanvasElement: Hittable {

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        switch self {
        case .primitive(let primitive):
            return primitive.hitTest(point, tolerance: tolerance)
        case .pin(let pin):
            return pin.hitTest(point, tolerance: tolerance)
        case .pad(let pad):
            return pad.hitTest(point, tolerance: tolerance)
        case .symbol(let symbol):
            return symbol.hitTest(point, tolerance: tolerance)
        case .connection(let connection):
            return connection.hitTest(point, tolerance: tolerance)
        }
    }
}

extension CanvasElement {
    mutating func moveTo(originalPosition  orig: CGPoint, offset delta: CGPoint) {
        switch self {
        case .primitive(var primitive):
            primitive.position = orig + delta; self = .primitive(primitive)
        case .pin(var pin):
            pin.position = orig + delta; self = .pin(pin)
        case .pad(var pad):
            pad.position = orig + delta; self = .pad(pad)
        case .symbol(var symbol):
            symbol.position = orig + delta; self = .symbol(symbol)
        case .connection(var connection):
            // For a connection, translate all vertices and mark dirty.

            self = .connection(connection)
        }
    }
}

extension CanvasElement {
    mutating func setRotation(_ angle: CGFloat) {
        switch self {
        case .primitive(var primitive): primitive.rotation = angle; self = .primitive(primitive)
        case .pin(var pin): pin.rotation = angle; self = .pin(pin)
        case .pad(var pad): pad.rotation = angle; self = .pad(pad)
        case .symbol(var symbol): symbol.rotation = angle; self = .symbol(symbol)
        case .connection:
            // Rotation of a whole net via a single angle is not a well-defined
            // operation without a clear pivot point. This is intentionally a no-op.
            // More specific rotation logic (e.g. rotating a selection of vertices)
            // would be handled differently.
            break
        }
    }
}
