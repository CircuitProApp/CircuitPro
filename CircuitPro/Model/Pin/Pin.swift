//
//  Pin.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

/// A pure data model representing a schematic pin.
///
/// This struct holds all the essential data for a pin but has no knowledge of how
/// to draw itself or how to be hit-tested. It serves as the data source for graph
/// components that provide rendering and interaction.
struct Pin: Identifiable, Codable, Hashable, Transformable {
    var id: UUID = UUID()
    var name: String
    var number: Int
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east
    var type: PinType
    var lengthType: PinLengthType = .regular
    var showLabel: Bool = true
    var showNumber: Bool = true
}

extension Pin {
    /// Provides a user-facing label for the pin.
    var label: String {
        name.isEmpty ? "Pin \(number)" : name
    }

    /// The rotation in radians. Conforms to `Transformable`.
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    var length: CGFloat {
        lengthType.cgFloatValue
    }
}
