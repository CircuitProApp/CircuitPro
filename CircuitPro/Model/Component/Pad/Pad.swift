//
//  Pad.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/5/25.
//

import SwiftUI

struct Pad: Identifiable, Codable, Hashable {

    var id: UUID = UUID()
    var number: Int
    var position: CGPoint
    var rotation: CardinalRotation = .deg0
    var shape: PadShape = .rect(width: 5, height: 10)
    var type: PadType = .surfaceMount
    var drillDiameter: Double?

}

extension Pad {
    var shapePrimitives: [AnyPrimitive] {
        switch shape {
        case let .rect(width, height):
            let rect = RectanglePrimitive(
                id: UUID(),
                size: CGSize(width: width, height: height),
                cornerRadius: 0,
                position: position,
                rotation: rotation.radians,
                strokeWidth: 1.0,
                filled: true,
                color: SDColor(color: .blue)
            )
            return [.rectangle(rect)]
        case .circle(let radius):
            let circle = CirclePrimitive(
                id: UUID(),
                radius: radius,
                position: position,
                rotation: rotation.radians,
                strokeWidth: 0.2,
                color: SDColor(color: .blue),
                filled: true
            )
            return [.circle(circle)]
        }
    }

    var maskPrimitives: [AnyPrimitive] {
        guard type == .throughHole, let drill = drillDiameter else { return [] }
        let mask = CirclePrimitive(
            id: UUID(),
            radius: drill / 2,
            position: position,
            rotation: rotation.radians,
            strokeWidth: 0,
            color: SDColor(color: .black),
            filled: true
        )
        return [.circle(mask)]
    }

    func systemHitTest(at point: CGPoint) -> Bool {
        shapePrimitives.contains { $0.systemHitTest(at: point) }
    }
}

extension Pad {
    var isCircle: Bool {
        if case .circle = shape { return true }
        return false
    }

    var radius: Double {
        get {
            if case let .circle(radius) = shape {
                return radius
            }
            return 0
        }
        set {
            shape = .circle(radius: newValue)
        }
    }

    var width: Double {
        get {
            if case let .rect(width, _) = shape {
                return width
            }
            return 0
        }
        set {
            if case let .rect(_, height) = shape {
                shape = .rect(width: newValue, height: height)
            }
        }
    }

    var height: Double {
        get {
            if case let .rect(_, height) = shape {
                return height
            }
            return 0
        }
        set {
            if case let .rect(width, _) = shape {
                shape = .rect(width: width, height: newValue)
            }
        }
    }
}
