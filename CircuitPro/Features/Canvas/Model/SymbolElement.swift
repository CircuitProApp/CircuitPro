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
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        return combined.copy(using: &transform)
    }
}

extension SymbolElement: Hittable {

    func hitTest(_ worldPoint: CGPoint, tolerance: CGFloat = 5) -> Bool {

        // map the probe into the symbol’s local space
        let local = worldPoint.applying(
            CGAffineTransform(translationX: position.x, y: position.y)
                .rotated(by: rotation)
                .inverted()
        )

        return
        symbol.primitives.contains { $0.hitTest(local, tolerance: tolerance) } ||
        symbol.pins.contains { $0.hitTest(local, tolerance: tolerance) }
    }
}

extension SymbolElement: Bounded {

    // 1 Axis-aligned box in world space
    var boundingBox: CGRect {

        // 1.1 Local-to-world transform shared by every child
        let transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)

        // 1.2 Local boxes of master primitives and pins
        let localBoxes = symbol.primitives.map(\.boundingBox) +
                         symbol.pins.map(\.boundingBox)

        // 1.3 Union after mapping each box into world space
        return localBoxes
            .map { $0.transformed(by: transform) }
            .reduce(CGRect.null) { $0.union($1) }
    }
}

private extension CGRect {

    // 1 Transformed axis-aligned bounding box
    func transformed(by transform: CGAffineTransform) -> CGRect {

        // 1.1 Corners in local space
        let corners = [
            origin,
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY)
        ]

        // 1.2 Map every corner and grow a rectangle around them
        var out = CGRect.null
        for point in corners.map({ $0.applying(transform) }) {
            out = out.union(CGRect(origin: point, size: .zero))
        }
        return out
    }
}
