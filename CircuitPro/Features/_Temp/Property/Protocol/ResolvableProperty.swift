//
//  ResolvableProperty.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

/// Defines a type that can be converted into a `ResolvedProperty` for UI display.
/// This protocol decouples the `PropertyResolver` from concrete model types.
protocol ResolvableProperty {
    
    /// Converts the conforming type into a display-ready `ResolvedProperty`.
    ///
    /// - Parameter overriddenValue: An optional value to use in place of the model's own value.
    ///   This is used by `PropertyDefinition` to apply an override from the instance.
    /// - Returns: A `ResolvedProperty` instance ready for the UI.
    func resolve(withOverriddenValue overriddenValue: PropertyValue?) -> ResolvedProperty
}
