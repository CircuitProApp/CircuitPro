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

extension SymbolElement: Transformable {

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

    // ─────────────────────────────────────────────────────────────
    // 1.  Normal appearance
    // ─────────────────────────────────────────────────────────────
    func drawBody(in ctx: CGContext) {
        ctx.saveGState()

        // Place the symbol instance in world space
        ctx.concatenate(
            CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
        )

        // Debugging rectangle
        let debugRect = CGRect(x: -10, y: -10, width: 20, height: 20)
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(debugRect)

        // Master primitives
        symbol.primitives.forEach { $0.drawBody(in: ctx) }

        // Pins are drawables themselves, so call their *body* only
        symbol.pins.forEach { $0.drawBody(in: ctx) }

        ctx.restoreGState()
    }

    // ─────────────────────────────────────────────────────────────
    // 2.  Outline that should glow when selected
    // ─────────────────────────────────────────────────────────────
    func selectionPath() -> CGPath? {

        // accumulate every path that makes up the symbol
        let combined = CGMutablePath()

        for prim in symbol.primitives {
            combined.addPath(prim.makePath())
        }
        for pin in symbol.pins {
            pin.primitives.forEach { combined.addPath($0.makePath()) }
        }

        // copy it into world space with the same transform we used to draw
        var t = CGAffineTransform(translationX: position.x,
                                  y: position.y)
                .rotated(by: rotation)

        return combined.copy(using: &t)
    }
}

extension SymbolElement: Hittable {

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
