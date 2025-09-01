import Observation
import SwiftUI
import Resolvable

@Observable
@ResolvableDestination(for: CircuitText.self)
final class SymbolInstance: Identifiable, Codable, Transformable {

    var id: UUID
    var definitionUUID: UUID
    
    @DefinitionSource(for: CircuitText.self, at: \SymbolDefinition.textDefinitions)
    var definition: SymbolDefinition? = nil
    
    var position: CGPoint
    var cardinalRotation: CardinalRotation = .east
    var textOverrides: [CircuitText.Override]
    var textInstances: [CircuitText.Instance]

    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closest(to: newValue) }
    }

    init(
        id: UUID = UUID(),
        definitionUUID: UUID,
        definition: SymbolDefinition? = nil,
        position: CGPoint,
        cardinalRotation: CardinalRotation = .east,
        textOverrides: [CircuitText.Override] = [],
        textInstances: [CircuitText.Instance] = []
    ) {
        self.id = id
        self.definitionUUID = definitionUUID
        self.definition = definition
        self.position = position
        self.cardinalRotation = cardinalRotation
        self.textOverrides = textOverrides
        self.textInstances = textInstances
    }

    // MARK: - Codable

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
    
    /// Creates a new instance with the same property values.
    func copy() -> SymbolInstance {
        SymbolInstance(id: id,
                       definitionUUID: definitionUUID,
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
        lhs.definitionUUID == rhs.definitionUUID &&
        lhs.position == rhs.position &&
        lhs.cardinalRotation == rhs.cardinalRotation &&
        lhs.textOverrides == rhs.textOverrides &&
        lhs.textInstances == rhs.textInstances
    }
}
