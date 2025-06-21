//
//  Pin.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

struct Pin: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var number: Int
    var position: CGPoint
    var rotation: CardinalRotation = .deg0
    var type: PinType
    var lengthType: PinLengthType = .long
    var showLabel: Bool = true
    var showNumber: Bool = true
}

extension Pin {
    var length: CGFloat {
        switch lengthType {
        case .short: return 40
        case .long:  return 60
        }
    }

    var label: String {
        name == "" ? "Pin \(number)" : name
    }

    var dir: CGPoint {
        rotation.direction
    }

    /// World-space start of the pin’s “leg”.
    var legStart: CGPoint {
        CGPoint(
            x: position.x + dir.x * length,
            y: position.y + dir.y * length
        )
    }

    var primitives: [AnyPrimitive] {
        let line = LinePrimitive(
            id: .init(),
            start: legStart,
            end: position,
            rotation: 0,          // geometry is already rotated
            strokeWidth: 1,
            color: .init(color: .blue)
        )

        let circle = CirclePrimitive(
            id: .init(),
            radius: 4,
            position: position,
            rotation: 0,
            strokeWidth: 1,
            color: .init(color: .blue),
            filled: false
        )

        return [.line(line), .circle(circle)]
    }

    func systemHitTest(at point: CGPoint) -> Bool {
        primitives.contains { $0.systemHitTest(at: point) }
    }
}
