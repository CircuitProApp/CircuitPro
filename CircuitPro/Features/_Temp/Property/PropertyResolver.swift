//
//  PropertyResolver.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

/// A stateless controller responsible for resolving component properties for UI display.
struct PropertyResolver {

    /// Resolves the properties from a component definition and its instance into a single list
    /// of display-ready `ResolvedProperty` view models.
    static func resolve(from definition: Component, and instance: ComponentInstance) -> [ResolvedProperty] {
        
        // Create a fast lookup for overridden values.
        let overrideValues = Dictionary(
            uniqueKeysWithValues: instance.propertyOverrides.map { ($0.definitionID, $0.value) }
        )

        // Process all properties defined in the master component.
        let definitionProperties = definition.propertyDefinitions.map { definition -> ResolvedProperty in
            let currentValue = overrideValues[definition.id] ?? definition.defaultValue
            
            return ResolvedProperty(
                source: .definition(definitionID: definition.id),
                key: definition.key,
                value: currentValue,
                unit: definition.unit
            )
        }

        // Process all ad-hoc properties stored on the instance.
        let instanceProperties = instance.adHocProperties.map { instance -> ResolvedProperty in
            return ResolvedProperty(
                source: .instance(instanceID: instance.id),
                key: instance.key,
                value: instance.value,
                unit: instance.unit
            )
        }

        return definitionProperties + instanceProperties
    }
}
