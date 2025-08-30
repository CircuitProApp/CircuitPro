//
//  TextSource.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import Foundation

/// Describes a data source for a text element by specifying a path to a property
/// within a `ComponentDefinition`, making it decoupled and extensible.
enum TextSource: Codable, Hashable {
    /// The text should display the component's name (e.g., "Resistor").
    case componentName
    
    /// The text should display the component's full reference designator (e.g., "R1").
    case componentReferenceDesignator
    
    /// The text is linked to a specific component property by its definition ID.
    case componentProperty(definitionID: UUID)
}
