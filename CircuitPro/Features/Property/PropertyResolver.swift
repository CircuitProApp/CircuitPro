//
//  PropertyResolver.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

struct PropertyResolver {

    static func resolve(from definition: Component, and instance: ComponentInstance) -> [ResolvedProperty] {
        
        // The override lookup remains the same.
        let overrideValues = Dictionary(
            uniqueKeysWithValues: instance.propertyOverrides.map { ($0.definitionID, $0.value) }
        )

        // The resolver is now beautifully simple. It just tells each definition to resolve itself,
        // passing in any relevant override.
        let definitionProperties = definition.propertyDefinitions.map {
            $0.resolve(withOverriddenValue: overrideValues[$0.id])
        }

        // The resolver tells each instance property to resolve itself.
        // There's no concept of an override here, so we pass nil.
        let instanceProperties = instance.propertyInstances.map {
            $0.resolve(withOverriddenValue: nil)
        }

        return definitionProperties + instanceProperties
    }
}
