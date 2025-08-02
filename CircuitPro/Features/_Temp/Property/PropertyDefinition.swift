//
//  PropertyDefinition.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

struct PropertyDefinition: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: PropertyKey
    var defaultValue: PropertyValue
    var unit: Unit
    var warnsOnEdit: Bool = false
}

extension PropertyDefinition: PropertyCore {
    /// Conformance to `PropertyCore`.
    /// This is a computed property that cleverly maps the protocol's `value` requirement
    /// to this type's specific `defaultValue` field.
    var value: PropertyValue {
        get { defaultValue }
        set { defaultValue = newValue }
    }
}

extension PropertyDefinition: ResolvableProperty {
    func resolve(withOverriddenValue overriddenValue: PropertyValue?) -> ResolvedProperty {
        // A definition uses the override if it exists, otherwise it falls back to its own default value.
        let finalValue = overriddenValue ?? self.defaultValue
        
        return ResolvedProperty(
            source: .definition(definitionID: self.id),
            key: self.key,
            value: finalValue,
            unit: self.unit
        )
    }
}
