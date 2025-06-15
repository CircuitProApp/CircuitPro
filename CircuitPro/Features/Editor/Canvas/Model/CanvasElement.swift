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

    var id: UUID {
        switch self {
        case .primitive(let primitive): return primitive.id
        case .pin(let pin):             return pin.id
        case .pad(let pad):             return pad.id
        }
    }

    var primitives: [AnyPrimitive] {
        switch self {
        case .primitive(let primitive): return [primitive]
        case .pin(let pin):             return pin.primitives
        case .pad(let pad):             return pad.shapePrimitives + pad.maskPrimitives
        }
    }

    var isPrimitiveEditable: Bool {
        switch self {
        case .primitive: return true
        case .pin, .pad: return false
        }
    }

    var debugDescription: String {
        switch self {
        case .primitive(let primitive): return "\(primitive)"
        case .pin(let pin):             return "\(pin)"
        case .pad(let pad):             return "\(pad)"
        }
    }

    var rotationDescription: String {
        switch self {
        case .primitive(let primitive): return "\(primitive.rotation * 180 / .pi)"
        default: return "no rotation"
        }
    }

    func draw(in ctx: CGContext, selected: Bool) {
        switch self {
        case .primitive(let primitive):
            primitive.draw(in: ctx, selected: selected)
        case .pin(let pin):
            pin.draw(in: ctx, showText: true, highlight: selected)
        case .pad(let pad):
            pad.draw(in: ctx, highlight: selected)
        }
    }

    func systemHitTest(at point: CGPoint) -> Bool {
        primitives.contains { $0.systemHitTest(at: point) }
    }

    func handles() -> [Handle] {
        primitives.flatMap { $0.handles() }
    }

    mutating func updateHandle(_ kind: Handle.Kind, to point: CGPoint, opposite: CGPoint?) {
        guard case .primitive = self else { return }

        var updatedPrimitives = primitives
        for index in updatedPrimitives.indices {
            updatedPrimitives[index].updateHandle(kind, to: point, opposite: opposite)
        }

        if updatedPrimitives.count == 1, let primitive = updatedPrimitives.first {
            self = .primitive(primitive)
        }
    }

    mutating func translate(by delta: CGPoint) {
        switch self {
        case .primitive(var primitive):
            primitive.position.x += delta.x
            primitive.position.y += delta.y
            self = .primitive(primitive)
        case .pin(var pin):
            pin.position.x += delta.x
            pin.position.y += delta.y
            self = .pin(pin)
        case .pad(var pad):
            pad.position.x += delta.x
            pad.position.y += delta.y
            self = .pad(pad)
        }
    }
}

extension CanvasElement {
    var isPin: Bool {
        if case .pin = self { return true } else { return false }
    }
    var isPad: Bool {
        if case .pad = self { return true } else { return false }
    }

}

// MARK: - CanvasElement bounding box
extension CanvasElement {
    var boundingBox: CGRect {
        primitives.map { $0.makePath().boundingBoxOfPath }
                  .reduce(.null, { $0.union($1) })
    }
}
