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
    var cardinalRotation: CardinalRotation = .west
    
    // 1. ADD THIS: Stores overrides for text defined in the master symbol.
    var anchoredTextOverrides: [AnchoredTextOverride]
    // 2. ADD THIS: Stores new text added only to this specific instance.
    var adHocTexts: [InstanceAdHocText]

    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(id: UUID = UUID(), symbolUUID: UUID, position: CGPoint, cardinalRotation: CardinalRotation = .west, anchoredTextOverrides: [AnchoredTextOverride] = [], adHocTexts: [InstanceAdHocText] = []) {
        self.id = id
        self.symbolUUID = symbolUUID
        self.position = position
        self.cardinalRotation = cardinalRotation
        self.anchoredTextOverrides = anchoredTextOverrides
        self.adHocTexts = adHocTexts
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _symbolUUID = "symbolUUID"
        case _position = "position"
        case _cardinalRotation = "rotation"
        case _anchoredTextOverrides = "anchoredTextOverrides"
        case _adHocTexts = "adHocTexts"
    }
    
    /// Creates a new instance with the same property values.
    func copy() -> SymbolInstance {
        SymbolInstance(id: id,
                       symbolUUID: symbolUUID,
                       position: position,
                       cardinalRotation: cardinalRotation,
                       anchoredTextOverrides: anchoredTextOverrides,
                       adHocTexts: adHocTexts
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
        lhs.anchoredTextOverrides == rhs.anchoredTextOverrides &&
        lhs.adHocTexts == rhs.adHocTexts
    }
}
