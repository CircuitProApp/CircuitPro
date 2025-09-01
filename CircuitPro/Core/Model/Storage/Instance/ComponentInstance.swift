//
//  ComponentInstance.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/14/25.
//

import Observation
import SwiftUI
import Resolvable

@Observable
@ResolvableDestination(for: Property.self)
final class ComponentInstance: Identifiable, Codable {

    var id: UUID
    var definitionUUID: UUID
    
    @DefinitionSource(for: Property.self, at: \ComponentDefinition.propertyDefinitions)
    var definition: ComponentDefinition? = nil
    
    var propertyOverrides: [Property.Override]
    var propertyInstances: [Property.Instance]

    var symbolInstance: SymbolInstance
    var footprintInstance: FootprintInstance?

    var referenceDesignatorIndex: Int

    init(
        id: UUID = UUID(),
        definitionUUID: UUID,
        definition: ComponentDefinition? = nil,
        propertyOverrides: [Property.Override] = [],
        propertyInstances: [Property.Instance] = [],
        symbolInstance: SymbolInstance,
        footprintInstance: FootprintInstance? = nil,
        reference: Int = 0
    ) {
        self.id = id
        self.definitionUUID = definitionUUID
        self.definition = definition
        self.propertyOverrides = propertyOverrides
        self.propertyInstances = propertyInstances
        self.symbolInstance = symbolInstance
        self.footprintInstance = footprintInstance
        self.referenceDesignatorIndex = reference
    }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case _definitionUUID = "definitionUUID"
        case _propertyOverrides = "propertyOverrides"
        case _propertyInstances = "propertyInstances"
        case _symbolInstance = "symbolInstance"
        case _footprintInstance = "footprintInstance"
        case _referenceDesignatorIndex = "referenceDesignatorIndex"
    }
}

// MARK: - Hashable
extension ComponentInstance: Hashable {
    public static func == (lhs: ComponentInstance, rhs: ComponentInstance) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ComponentInstance {
    /// A helper to resolve the properties of this specific instance.
    /// This replaces the logic that was previously on `DesignComponent`.
    var displayedProperties: [Property.Resolved] {
        // Gracefully handle the case where the definition is missing.
        guard let definition = self.definition else { return [] }
        
        return Property.Resolver.resolve(
            definitions: definition.propertyDefinitions,
            overrides: self.propertyOverrides,
            instances: self.propertyInstances
        )
    }
}
