//
//  DesignComponent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI

struct DesignComponent: Identifiable, Hashable {

    // SwiftData model
    let definition: Component

    // NSDocument model
    let instance: ComponentInstance

    var id: UUID { instance.id }

    var referenceDesignator: String {
        definition.referenceDesignatorPrefix + instance.referenceDesignatorIndex.description
    }
    
    /// The properties are now resolved by our dedicated controller.
    var displayedProperties: [ResolvedProperty] {
        return PropertyResolver.resolve(from: definition, and: instance)
    }
    
    /// When the UI makes an edit, it can call this simple method.
    func save(editedProperty: ResolvedProperty) {
        // The instance itself knows how to handle the commit logic.
        instance.commit(changeTo: editedProperty)
    }
}
