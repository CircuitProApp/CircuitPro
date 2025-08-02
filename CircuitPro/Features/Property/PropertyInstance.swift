//
//  PropertyInstance.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

/// Defines a full, self-contained property added to a single component instance at runtime.
/// It does not correspond to a PropertyDefinition in the master component.
struct PropertyInstance: PropertyCore, Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: PropertyKey
    var value: PropertyValue
    var unit: Unit
}

extension PropertyInstance: ResolvableProperty {
    func resolve(withOverriddenValue overriddenValue: PropertyValue?) -> ResolvedProperty {
        // An instance property is self-contained and cannot be overridden.
        // We therefore ignore the `overriddenValue` parameter.
        return ResolvedProperty(
            source: .instance(instanceID: self.id),
            key: self.key,
            value: self.value,
            unit: self.unit
        )
    }
}
