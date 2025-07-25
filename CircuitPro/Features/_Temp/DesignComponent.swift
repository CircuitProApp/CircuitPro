//
//  DesignComponent.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI

struct DesignComponent: Identifiable, Hashable {

    // library object (SwiftData)
    let definition: Component

    // stored in the NSDocument
    let instance: ComponentInstance

    var id: UUID { instance.id }

    var reference: String {
        definition.abbreviation + instance.reference.description
    }
    
    var displayedProperties: [DisplayedProperty] {
        // 1. Create a fast lookup dictionary for overrides.
        //    [DefinitionID: OverriddenValue]
        let overrideValues = Dictionary(
            uniqueKeysWithValues: instance.propertyOverrides.map { ($0.definitionID, $0.value) }
        )

        // 2. Process all properties defined in the master component.
        let definedProperties = definition.propertyDefinitions.map { def -> DisplayedProperty in
            // Use the override value if it exists, otherwise use the library default.
            let currentValue = overrideValues[def.id] ?? def.defaultValue
            
            return DisplayedProperty(
                id: def.id, // Use the definition's ID as the stable ID
                key: def.key ?? .basic(.capacitance),
                value: currentValue,
                unit: def.unit,
                sourceDefinitionID: def.id // Mark that it comes from a definition
            )
        }

        // 3. Process all ad-hoc properties stored on the instance.
        let adHocProperties = instance.adHocProperties.map { adHoc -> DisplayedProperty in
            return DisplayedProperty(
                id: adHoc.id, // Use its own unique ID
                key: adHoc.key,
                value: adHoc.value,
                unit: adHoc.unit,
                sourceDefinitionID: nil // Mark that it has no definition
            )
        }

        // 4. Return the combined list.
        return definedProperties + adHocProperties
    }
}
