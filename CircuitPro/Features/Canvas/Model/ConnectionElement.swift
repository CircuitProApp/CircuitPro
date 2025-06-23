//
//  ConnectionElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {
    let id: UUID
        var segments: [(CGPoint, CGPoint)]     // absolute world-space points

        // Transformable
        var position: CGPoint  = .zero         // not really meaningful, but required
        var rotation: CGFloat  = 0             // (unused; see note below)

        // MARK:  Convenience
        var primitives: [AnyPrimitive] {
            segments.map { start, end in
                AnyPrimitive.line(
                    LinePrimitive(
                        id: UUID(),
                        start: start,
                        end:   end,
                        rotation: 0,
                        strokeWidth: 1,
                        color: SDColor(color: .blue)
                    )
                )
            }
        }

        // MARK:  Drawable  -------------------------------------------------
        func drawBody(in ctx: CGContext) {
            primitives.forEach { $0.drawBody(in: ctx) }
        }

        func selectionPath() -> CGPath? {
            let path = CGMutablePath()
            primitives.forEach { path.addPath($0.makePath()) }
            return path
        }

        // MARK:  Hittable  -------------------------------------------------
        func hitTest(_ p: CGPoint, tolerance: CGFloat = 5) -> Bool {
            primitives.contains { $0.hitTest(p, tolerance: tolerance) }
        }
}

extension ConnectionElement: Equatable, Hashable {
    static func == (lhs: ConnectionElement, rhs: ConnectionElement) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
