//
//  PropertyOverride.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

struct PropertyOverride: Identifiable, Codable, Hashable {
    let definitionID: UUID
    var value: PropertyValue
    var id: UUID { definitionID }
}
