//
//  TextSource.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import Foundation

/// Describes the origin of an anchored text's content.
enum TextSource: Codable, Hashable {
    /// The component's unique referenceDesignatorIndex designator (e.g., "R1", "C2").
    case reference
    case componentName
    case property(definitionID: UUID)
}
