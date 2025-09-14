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
// ADDED: Make this a destination for resolving text, and make it transformable.
@ResolvableDestination(for: CircuitText.self)
final class FootprintInstance: Identifiable, Codable, Transformable {

    var id: UUID
    
    // RENAMED: Changed from footprintUUID to definitionUUID for consistency with SymbolInstance.
    var definitionUUID: UUID

    // ADDED: A source link to the FootprintDefinition to get the text definitions.
    @DefinitionSource(for: CircuitText.self, at: \FootprintDefinition.textDefinitions)
    var definition: FootprintDefinition? = nil
    
    // ADDED: Transformable properties for position and rotation on the PCB.
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east

    // ADDED: Properties to store instance-specific text data.
    var textOverrides: [CircuitText.Override]
    var textInstances: [CircuitText.Instance]

    // ADDED: Computed property to satisfy Transformable conformance.
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(
        id: UUID = UUID(),
        definitionUUID: UUID,
        definition: FootprintDefinition? = nil,
        position: CGPoint = .zero, // Added
        cardinalRotation: CardinalRotation = .east, // Added
        textOverrides: [CircuitText.Override] = [], // Added
        textInstances: [CircuitText.Instance] = [] // Added
    ) {
        self.id = id
        self.definitionUUID = definitionUUID
        self.definition = definition
        self.position = position
        self.cardinalRotation = cardinalRotation
        self.textOverrides = textOverrides
        self.textInstances = textInstances
    }

    // MARK: - Codable (Updated to handle all new properties)

    enum CodingKeys: String, CodingKey {
        case id
        case definitionUUID
        case position
        case cardinalRotation
        case textOverrides
        case textInstances
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.definitionUUID = try container.decode(UUID.self, forKey: .definitionUUID)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.cardinalRotation = try container.decode(CardinalRotation.self, forKey: .cardinalRotation)
        self.textOverrides = try container.decode([CircuitText.Override].self, forKey: .textOverrides)
        self.textInstances = try container.decode([CircuitText.Instance].self, forKey: .textInstances)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(definitionUUID, forKey: .definitionUUID)
        try container.encode(position, forKey: .position)
        try container.encode(cardinalRotation, forKey: .cardinalRotation)
        try container.encode(textOverrides, forKey: .textOverrides)
        try container.encode(textInstances, forKey: .textInstances)
    }
}

// ADDED: Equatable conformance for value-based comparisons.
extension FootprintInstance: Equatable {
    static func == (lhs: FootprintInstance, rhs: FootprintInstance) -> Bool {
        lhs.id == rhs.id &&
        lhs.definitionUUID == rhs.definitionUUID &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation &&
        lhs.textOverrides == rhs.textOverrides &&
        lhs.textInstances == rhs.textInstances
    }
}
