//
//  ConnectionElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct ConnectionSegment: Identifiable, Equatable, Hashable {
    let id: UUID
    var start: CGPoint
    var end: CGPoint
}

struct ConnectionElement: Identifiable, Drawable, Hittable, Transformable {
    let id: UUID
    var segments: [ConnectionSegment]

        // Transformable
        var position: CGPoint  = .zero         // not really meaningful, but required
        var rotation: CGFloat  = 0             // (unused; see note below)

        // MARK:  Convenience
    var primitives: [AnyPrimitive] {
        segments.map { seg in
            AnyPrimitive.line(
                LinePrimitive(
                    id: seg.id,
                    start: seg.start,
                    end:   seg.end,
                    rotation: 0,
                    strokeWidth: 1,
                    color: SDColor(color: .blue)
                )
            )
        }
    }
    // MARK: – Drawable -------------------------------------------------
    func drawBody(in ctx: CGContext) {
        primitives.forEach { $0.drawBody(in: ctx) }
    }

    func selectionPath() -> CGPath? {
        let path = CGMutablePath()
        primitives.forEach { path.addPath($0.makePath()) }
        return path
    }

    // MARK: – Hittable -------------------------------------------------
    func hitTest(_ point: CGPoint, tolerance: CGFloat = 5) -> Bool {
        primitives.contains { $0.hitTest(point, tolerance: tolerance) }
    }

    /// Returns the UUID of the segment that was hit, if any.
    /// Useful for code that wants to distinguish individual tracks.
    func hitSegmentID(at point: CGPoint,
                      tolerance: CGFloat = 5) -> UUID? {
        primitives.first { $0.hitTest(point, tolerance: tolerance) }?.id
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
