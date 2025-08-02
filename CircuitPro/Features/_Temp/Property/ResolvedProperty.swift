//
//  ResolvedProperty.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import SwiftUI
/// A unified view model representing a property to be displayed in the UI.
/// It has been "resolved" from its source (definition or ad-hoc) and is ready for display and editing.
struct ResolvedProperty: Identifiable, Hashable {
    /// A stable ID for SwiftUI, derived from the source.
    var id: UUID {
        switch source {
        case .definition(let definitionID):
            return definitionID
        case .instance(let instanceID):
            return instanceID
        }
    }
    
    /// The underlying source of the property.
    let source: PropertySource

    /// The property key (e.g., Resistance, Tolerance).
    let key: PropertyKey
    
    /// The final, current value to be displayed and edited.
    var value: PropertyValue
    
    /// The unit for the property.
    let unit: Unit
}
