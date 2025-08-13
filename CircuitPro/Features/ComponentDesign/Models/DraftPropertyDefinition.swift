//
//  DraftPropertyDefinition.swift
//  CircuitPro
//
//  Created by Gemini on 8/1/25.
//

import Foundation

/// A temporary, UI-facing model for defining a component property.
/// The `key` is optional because a user can add a new row to the table
/// before selecting a property type.
struct DraftProperty: Identifiable {
    var id: UUID = UUID()
    var key: PropertyKey?
    var value: PropertyValue
    var unit: Unit
    var warnsOnEdit: Bool = false
}
