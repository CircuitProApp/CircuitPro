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
    case componentAttribute(ComponentDefinition.AttributeSource)
    case componentProperty(definitionID: UUID)
}
