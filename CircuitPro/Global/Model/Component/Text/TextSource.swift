//
//  TextSource.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import Foundation

/// Describes the origin of an anchored text's content, allowing for
/// both static and dynamically resolved text.
enum TextSource: Codable, Hashable {
    /// The text is a fixed, static string.
    case `static`(String)
    
    /// The text is dynamic and derived from a component property.
    case dynamic(DynamicProperty)
}

/// Specifies which dynamic property of a component should be displayed.
enum DynamicProperty: Codable, Hashable {
    /// The component's unique referenceDesignatorIndex designator (e.g., "R1", "C2").
    case reference
    case componentName
    
    case property(definitionID: UUID)
}
