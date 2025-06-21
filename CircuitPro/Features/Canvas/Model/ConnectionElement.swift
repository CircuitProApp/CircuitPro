//
//  ConnectionElement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 19.06.25.
//

import SwiftUI

struct ConnectionElement: Identifiable {
    let id: UUID
    var segments: [(CGPoint, CGPoint)]
    
    var primitives: [AnyPrimitive] {
        segments.map { segment in
            AnyPrimitive.line(LinePrimitive(id: UUID(), start: segment.0, end: segment.1, rotation: 0, strokeWidth: 1, color: SDColor(color: .blue)))
        }
    }
    
    // Hit Testing
    func hitTest(at point: CGPoint, tolerance: CGFloat = 5.0) -> Bool {
        for primitive in primitives {
            if primitive.systemHitTest(at: point, tolerance: tolerance) {
                return true
            }
        }
        return false
    }

    // Draw with selection highlight
    func draw(in ctx: CGContext, selected: Bool) {
        for primitive in primitives {
            primitive.draw(in: ctx, selected: selected)
        }
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
