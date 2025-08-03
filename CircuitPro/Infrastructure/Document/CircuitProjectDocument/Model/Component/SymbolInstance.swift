//
//  SymbolInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI

@Observable
final class SymbolInstance: Identifiable, Codable, Transformable {

    var id: UUID

    var symbolUUID: UUID
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east
    
    // 1. ADD THIS: Stores overrides for text defined in the master symbol.
    var textOverrides: [TextOverride]
    // 2. ADD THIS: Stores new text added only to this specific instance.
    var textInstances: [TextInstance]

    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(id: UUID = UUID(), symbolUUID: UUID, position: CGPoint, cardinalRotation: CardinalRotation = .east, textOverrides: [TextOverride] = [], textInstances: [TextInstance] = []) {
        self.id = id
        self.symbolUUID = symbolUUID
        self.position = position
        self.cardinalRotation = cardinalRotation
        self.textOverrides = textOverrides
        self.textInstances = textInstances
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _symbolUUID = "symbolUUID"
        case _position = "position"
        case _cardinalRotation = "rotation"
        case _textOverrides = "textOverrides"
        case _textInstances = "textInstances"
    }
    
    /// Creates a new instance with the same property values.
    func copy() -> SymbolInstance {
        SymbolInstance(id: id,
                       symbolUUID: symbolUUID,
                       position: position,
                       cardinalRotation: cardinalRotation,
                       textOverrides: textOverrides,
                       textInstances: textInstances
        )
    }
}

// Add Equatable conformance to allow value-based comparisons.
extension SymbolInstance: Equatable {
    static func == (lhs: SymbolInstance, rhs: SymbolInstance) -> Bool {
        lhs.id == rhs.id &&
        lhs.symbolUUID == rhs.symbolUUID &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation &&
        lhs.textOverrides == rhs.textOverrides &&
        lhs.textInstances == rhs.textInstances
    }
}
