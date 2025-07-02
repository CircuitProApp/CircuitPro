//
//  Pad.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/5/25.
//
//

import SwiftUI

/// A single copper pad on a footprint – draws by delegating
/// to one or two underlying primitives.
struct Pad: Identifiable, Codable, Hashable {

    // ───────────── data
    var id: UUID = UUID()
    var number: Int
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .deg0          // stored
    var shape: PadShape = .rect(width: 5, height: 10)
    var type: PadType = .surfaceMount
    var drillDiameter: Double?
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Transformable
// ═══════════════════════════════════════════════════════════════════════
extension Pad: Transformable {

    // bridge enum ⇄ radians so the rest of the canvas can treat the pad
    // just like any continuously-rotated item.
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Private helpers
// ═══════════════════════════════════════════════════════════════════════
extension Pad {

    // geometry rendered on the copper layer
    var shapePrimitives: [AnyPrimitive] {
        switch shape {

        case let .rect(width, height):
            let rect = RectanglePrimitive(
                id: UUID(),
                size: CGSize(width: width, height: height),
                cornerRadius: 0,
                position: position,
                rotation: rotation,                // already in radians
                strokeWidth: 1,
                filled: true,
                color: .init(color: .blue)
            )
            return [.rectangle(rect)]

        case let .circle(radius):
            let circle = CirclePrimitive(
                id: UUID(),
                radius: radius,
                position: position,
                rotation: rotation,
                strokeWidth: 0.2,
                color: .init(color: .blue),
                filled: true
            )
            return [.circle(circle)]
        }
    }

    // mask for through-hole drills
    var maskPrimitives: [AnyPrimitive] {
        guard type == .throughHole, let drill = drillDiameter else { return [] }
        let mask = CirclePrimitive(
            id: UUID(),
            radius: drill / 2,
            position: position,
            rotation: rotation,
            strokeWidth: 0,
            color: .init(color: .black),
            filled: true
        )
        return [.circle(mask)]
    }

    var allPrimitives: [AnyPrimitive] { shapePrimitives + maskPrimitives }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Drawable & Hittable
// ═══════════════════════════════════════════════════════════════════════
extension Pad: Hittable {

    func hitTest(_ p: CGPoint, tolerance t: CGFloat) -> Bool {
        allPrimitives.contains { $0.hitTest(p, tolerance: t) }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Convenience computed properties (width / height / radius)
// ═══════════════════════════════════════════════════════════════════════
extension Pad {

    var isCircle: Bool {
        if case .circle = shape { return true }
        return false
    }

    var radius: Double {
        get { if case let .circle(r) = shape { r } else { 0 } }
        set { shape = .circle(radius: newValue) }
    }

    var width: Double {
        get { if case let .rect(w, _) = shape { w } else { 0 } }
        set { if case let .rect(_, h) = shape { shape = .rect(width: newValue, height: h) } }
    }

    var height: Double {
        get { if case let .rect(_, h) = shape { h } else { 0 } }
        set { if case let .rect(w, _) = shape { shape = .rect(width: w, height: newValue) } }
    }
}
