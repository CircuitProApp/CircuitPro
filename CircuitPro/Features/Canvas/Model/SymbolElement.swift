//
//  SymbolElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct SymbolElement: Identifiable {

    let id: UUID

    // MARK: Instance-specific data
    var instance: SymbolInstance     // position, rotation … (mutable)

    // MARK: Library master (immutable, reference type → no copy cost)
    let symbol: Symbol


    var primitives: [AnyPrimitive] {
        symbol.primitives + symbol.pins.flatMap(\.primitives)
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

extension SymbolElement: Placeable {

    var position: CGPoint {
        get { instance.position }
        set { instance.position = newValue }
    }

    var rotation: CGFloat {
        get { instance.rotation }
        set { instance.rotation = newValue }
    }
}

extension SymbolElement: Drawable {

    func draw(in ctx: CGContext, selected: Bool) {

        ctx.saveGState()
        ctx.concatenate(
            CGAffineTransform(translationX: position.x,
                              y: position.y)
            .rotated(by: rotation)
        )

        // primitives belonging to the symbol master
        symbol.primitives.forEach { $0.draw(in: ctx, selected: selected) }

        // pins are already Drawables in their own right
        symbol.pins.forEach { $0.draw(in: ctx, selected: selected) }

        ctx.restoreGState()
    }
}

extension SymbolElement: Tappable {

    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> Bool {

        // map the probe into the symbol’s local space
        let local = worldPoint.applying(
            CGAffineTransform(translationX: position.x,
                              y: position.y)
            .rotated(by: rotation)
            .inverted()
        )

        return symbol.primitives.contains { $0.hitTest(local, tolerance: tolerance) } ||
               symbol.pins.contains      { $0.hitTest(local, tolerance: tolerance) }
    }
}
