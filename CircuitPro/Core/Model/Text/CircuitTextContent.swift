//
//  CircuitTextContent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import Foundation

/// Describes a data source for a text element by specifying a path to a property
/// within a `ComponentDefinition`, making it decoupled and extensible.
enum CircuitTextContent: Codable, Hashable {
    /// The text is static and its value is stored directly in the `text` property.
    case `static`(text: String)
    
    /// The text should display the component's name (e.g., "Resistor").
    case componentName
    
    /// The text should display the component's full reference designator (e.g., "R1").
    case componentReferenceDesignator
    
    /// The text is linked to a specific component property by its definition ID.
    case componentProperty(definitionID: UUID, options: TextDisplayOptions)
}

extension CircuitTextContent {
    var displayOptions: TextDisplayOptions? {
        if case .componentProperty(_, let options) = self {
            return options
        }
        return nil
    }
}
