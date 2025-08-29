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
    
    var referenceDesignator: String {
        "\(definition.referenceDesignatorPrefix)\(instance.referenceDesignatorIndex)"
    }
    
    /// Provides type-safe access to component attributes using the generated `AttributeSource`.
    /// This allows for clean, safe syntax like `component[.name]`.
    subscript(source: ComponentDefinition.AttributeSource) -> String {
        // It simply delegates to the dynamic member subscript using the underlying string key.
        if source == .referenceDesignatorPrefix {
            return self.referenceDesignator
        }
        return self[dynamicMember: source.key]
    }
    
    /// Provides dynamic access to component attributes via the generated KeyPath lookup table.
    subscript(dynamicMember key: String) -> String {
        // Next, use the auto-generated lookup table to find the real KeyPath.
        if let keyPath = ComponentDefinition._keyPath(for: key) {
            let value = definition[keyPath: keyPath]
            return String(describing: value)
        }
        
        // Final fallback if the key is invalid.
        return "n/a"
    }
}
