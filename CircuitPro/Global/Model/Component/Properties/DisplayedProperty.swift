//
//  DisplayedProperty.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//


import Foundation

struct DisplayedProperty: Identifiable {
    /// A stable ID for SwiftUI lists.
    let id: UUID
    
    /// The property key (e.g., Resistance, Tolerance).
    let key: PropertyKey
    
    /// The final, current value to be displayed and edited.
    var value: PropertyValue
    
    /// The unit for the property.
    let unit: Unit
    
    // --- This is the magic ---
    /// If non-nil, this is the ID of the master `PropertyDefinition`.
    /// If nil, this property is an ad-hoc one stored on the instance.
    /// This tells us how to save any edits.
    let sourceDefinitionID: UUID?
}