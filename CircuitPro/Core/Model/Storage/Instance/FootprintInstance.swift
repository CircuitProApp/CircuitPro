//
//  FootprintInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI
import Resolvable

@Observable
@ResolvableDestination(for: CircuitText.self)
final class FootprintInstance: Identifiable, Codable, Transformable {

    var id: UUID
    var definitionUUID: UUID

    @DefinitionSource(for: CircuitText.self, at: \FootprintDefinition.textDefinitions)
    var definition: FootprintDefinition? = nil
    
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east

    /// The placement status and location of the footprint, e.g., unplaced, or placed on the front/back side.
    var placement: PlacementState = .unplaced
    
    var textOverrides: [CircuitText.Override]
    var textInstances: [CircuitText.Instance]

    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(
        id: UUID = UUID(),
        definitionUUID: UUID,
        definition: FootprintDefinition? = nil,
        position: CGPoint = .zero,
        cardinalRotation: CardinalRotation = .east,
        placement: PlacementState = .unplaced,
        textOverrides: [CircuitText.Override] = [],
        textInstances: [CircuitText.Instance] = []
    ) {
        self.id = id
        self.definitionUUID = definitionUUID
        self.definition = definition
        self.position = position
        self.cardinalRotation = cardinalRotation
        self.placement = placement
        self.textOverrides = textOverrides
        self.textInstances = textInstances
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case definitionUUID
        case position
        case cardinalRotation
        case placement // Updated from 'side' and 'isPlaced'
        case textOverrides
        case textInstances
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.definitionUUID = try container.decode(UUID.self, forKey: .definitionUUID)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.cardinalRotation = try container.decode(CardinalRotation.self, forKey: .cardinalRotation)
        // Decode the new state, defaulting to .unplaced for backward compatibility with older project files.
        self.placement = try container.decodeIfPresent(PlacementState.self, forKey: .placement) ?? .unplaced
        self.textOverrides = try container.decode([CircuitText.Override].self, forKey: .textOverrides)
        self.textInstances = try container.decode([CircuitText.Instance].self, forKey: .textInstances)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(definitionUUID, forKey: .definitionUUID)
        try container.encode(position, forKey: .position)
        try container.encode(cardinalRotation, forKey: .cardinalRotation)
        try container.encode(placement, forKey: .placement)
        try container.encode(textOverrides, forKey: .textOverrides)
        try container.encode(textInstances, forKey: .textInstances)
    }
}

// MARK: - Equatable Conformance

extension FootprintInstance: Equatable {
    static func == (lhs: FootprintInstance, rhs: FootprintInstance) -> Bool {
        // Note: 'definition' is a transient property and should not be part of Equatable comparison.
        lhs.id == rhs.id &&
        lhs.definitionUUID == rhs.definitionUUID &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation &&
        lhs.placement == rhs.placement && // Updated to use the new state enum
        lhs.textOverrides == rhs.textOverrides &&
        lhs.textInstances == rhs.textInstances
    }
}
