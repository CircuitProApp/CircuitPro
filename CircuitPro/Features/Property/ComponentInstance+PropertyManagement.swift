//
//  ComponentInstance+PropertyManagement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

extension ComponentInstance {
    
    /// Updates the instance's properties based on a change to a `PropertyResolved` view model.
    func update(with editedProperty: ResolvedProperty) {
        switch editedProperty.source {
            
        case .definition(let definitionID):
            if let index = self.propertyOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                self.propertyOverrides[index].value = editedProperty.value
            } else {
                let newOverride = PropertyOverride(definitionID: definitionID, value: editedProperty.value)
                self.propertyOverrides.append(newOverride)
            }
            
        case .instance(let instancePropertyID):
            // This now correctly references the renamed `propertyInstances` property.
            if let index = self.propertyInstances.firstIndex(where: { $0.id == instancePropertyID }) {
                self.propertyInstances[index].value = editedProperty.value
                self.propertyInstances[index].key = editedProperty.key
            }
        }
    }

    /// Adds a new, user-created property directly to this instance.
    /// The signature has been corrected to accept the correct data model type.
    func add(_ newProperty: PropertyInstance) {
        self.propertyInstances.append(newProperty)
    }

    /// Removes a property from this instance.
    func remove(_ propertyToRemove: ResolvedProperty) {
        switch propertyToRemove.source {
            
        case .definition(let definitionID):
            self.propertyOverrides.removeAll { $0.definitionID == definitionID }
            
        case .instance(let instancePropertyID):
            // This now correctly references the renamed `propertyInstances` property.
            self.propertyInstances.removeAll { $0.id == instancePropertyID }
        }
    }
}
