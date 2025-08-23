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

    var displayedProperties: [Property.Resolved] {
        return Property.Resolver.resolve(
            definitions: definition.propertyDefinitions,
            overrides: instance.propertyOverrides,
            instances: instance.propertyInstances
        )
    }
}
