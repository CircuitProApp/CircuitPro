//
//  DesignComponent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI

@dynamicMemberLookup
struct DesignComponent: Identifiable, Hashable {

    // The sources of truth
    let definition: ComponentDefinition
    let instance: ComponentInstance

    var id: UUID { instance.id }

    var displayedProperties: [Property.Resolved] {
        return Property.Resolver.resolve(
            definitions: definition.propertyDefinitions,
            overrides: instance.propertyOverrides,
            instances: instance.propertyInstances
        )
    }
    
    /// Provides type-safe access to component attributes using the generated `AttributeSource`.
    /// This allows for clean, safe syntax like `component[.name]`.
    subscript(source: ComponentDefinition.AttributeSource) -> String {
        // It simply delegates to the dynamic member subscript using the underlying string key.
        return self[dynamicMember: source.key]
    }
    
    /// Provides dynamic access to component attributes via string keys.
    /// This is the engine that powers both `@dynamicMemberLookup` and the type-safe subscript.
    subscript(dynamicMember key: String) -> String {
        if key == "referenceDesignator" {
            return "\(definition.referenceDesignatorPrefix)\(instance.referenceDesignatorIndex)"
        }
        
        let mirror = Mirror(reflecting: definition)
        if let propertyValue = mirror.descendant(key) {
            return String(describing: propertyValue)
        }
        
        return "n/a"
    }
}
