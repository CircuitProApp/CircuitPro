//
//  PropertyDefinition.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

struct PropertyDefinition: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: PropertyKey?
    var defaultValue: PropertyValue
    var unit: Unit
    var warnsOnEdit: Bool = false
}
