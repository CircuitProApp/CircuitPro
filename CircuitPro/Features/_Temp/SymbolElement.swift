//
//  SymbolElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct SymbolElement: Identifiable {

    // MARK: Identity
    let id: UUID                     // normally the ComponentInstance.id

    // MARK: Instance-specific data
    var instance: SymbolInstance     // position, rotation … (mutable)

    // MARK: Library master (immutable, reference type → no copy cost)
    let symbol: Symbol

    // ═══════════════════════════════════════════════════════════════════════
    //  Internal helpers
    // ═══════════════════════════════════════════════════════════════════════
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: instance.position.x,
                          y: instance.position.y)
        .rotated(by: instance.rotation.radians)
    }

    var primitives: [AnyPrimitive] {
        symbol.primitives + symbol.pins.flatMap(\.primitives)
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  CanvasElement behaviour
    // ═══════════════════════════════════════════════════════════════════════
    func draw(in ctx: CGContext, selected: Bool) {
        ctx.saveGState()
        ctx.concatenate(transform)

        // primitives need to know whether the symbol is selected
        symbol.primitives.forEach { $0.draw(in: ctx, selected: selected) }

        // pins already receive the flag
        symbol.pins.forEach {
            $0.draw(in: ctx, showText: true, highlight: selected)
        }

        ctx.restoreGState()
    }
    
    var effectivePosition: CGPoint {
        instance.position
    }

    func systemHitTest(at point: CGPoint) -> Bool {
        let local = point.applying(transform.inverted())
        return symbol.primitives.contains { $0.systemHitTest(at: local) } ||
               symbol.pins.contains      { $0.systemHitTest(at: local) }
    }

    func handles() -> [Handle] { [] }      // treat whole symbol as rigid

    mutating func translate(by delta: CGPoint) {
        instance.position.x += delta.x
        instance.position.y += delta.y
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  Equality & Hashing based solely on the element’s id
// ═══════════════════════════════════════════════════════════════════════
extension SymbolElement: Equatable, Hashable {
    static func == (lhs: SymbolElement, rhs: SymbolElement) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
