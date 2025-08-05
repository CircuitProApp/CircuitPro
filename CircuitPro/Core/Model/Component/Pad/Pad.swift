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
    var cardinalRotation: CardinalRotation = .east    
    var shape: PadShape = .rect(width: 5, height: 10)
    var type: PadType = .surfaceMount
    var drillDiameter: Double?
}

extension Pad: Transformable {

    // bridge enum ⇄ radians so the rest of the canvas can treat the pad
    // just like any continuously-rotated item.
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }
}

// MARK: - Convenience computed properties (width / height / radius)
extension Pad {

    var isCircle: Bool {
        if case .circle = shape { return true }
        return false
    }

    var radius: Double {
        get { if case let .circle(radius) = shape { radius } else { 0 } }
        set { shape = .circle(radius: newValue) }
    }

    var width: Double {
        get { if case let .rect(width, _) = shape { width } else { 0 } }
        set { if case let .rect(_, height) = shape { shape = .rect(width: newValue, height: height) } }
    }

    var height: Double {
        get { if case let .rect(_, height) = shape { height } else { 0 } }
        set { if case let .rect(width, _) = shape { shape = .rect(width: width, height: newValue) } }
    }
}
