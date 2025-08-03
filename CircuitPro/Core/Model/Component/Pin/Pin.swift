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
    var cardinalRotation: CardinalRotation = .east
    var type: PinType
    var lengthType: PinLengthType = .long
    var showLabel: Bool = true
    var showNumber: Bool = true
}

extension Pin: Transformable {
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }
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

    /// World-space start of the pin’s "leg".
    ///
    /// Using `cardinalRotation.direction` ensures the leg follows
    /// the expected cardinal orientation. Prior logic relied on
    /// `rotation` which treated 0° as pointing west, leading to
    /// inverted left/right behaviour when rotating pins.
    var legStart: CGPoint {
        let dir = cardinalRotation.direction
        return CGPoint(
            x: position.x + dir.x * length,
            y: position.y + dir.y * length
        )
    }

    var primitives: [AnyPrimitive] {
        let line = LinePrimitive(
            id: .init(),
            start: legStart,
            end: position,
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

        return [.circle(circle), .line(line)]
    }
}
