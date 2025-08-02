//
//  ComponentInstance+PropertyManagement.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import Foundation

extension ComponentInstance {
    
    /// Updates the instance's properties based on a change to a `PropertyResolved` view model.
    /// This method replaces the older `commit(changeTo:)` method.
    func update(with editedProperty: ResolvedProperty) {
        switch editedProperty.source {
            
        case .definition(let definitionID):
            // The user edited a property that came from a library definition.
            // We must create or update an override.
            if let index = self.propertyOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // An override for this property already exists, so update its value.
                self.propertyOverrides[index].value = editedProperty.value
            } else {
                // No override exists yet, so create a new one.
                let newOverride = PropertyOverride(definitionID: definitionID, value: editedProperty.value)
                self.propertyOverrides.append(newOverride)
            }
            
        case .instance(let instancePropertyID):
            // The user edited an instance-specific property.
            // We find it by its unique ID and update it directly.
            // This now correctly references `propertyInstances` instead of `adHocProperties`.
            if let index = self.propertyInstances.firstIndex(where: { $0.id == instancePropertyID }) {
                self.propertyInstances[index].value = editedProperty.value
                // Unlike overrides, the key of an instance property can also be changed.
                self.propertyInstances[index].key = editedProperty.key
            }
        }
    }

    /// Adds a new, user-created property directly to this instance.
    /// This logic has been moved from the ProjectManager.
    func add(_ newProperty: ResolvedProperty) {
        self.propertyInstances.append(newProperty)
    }

    /// Removes a property from this instance.
    /// This intelligently handles resetting an override or deleting an instance property.
    /// This logic has also been moved from the ProjectManager.
    func remove(_ propertyToRemove: ResolvedProperty) {
        switch propertyToRemove.source {
            
        case .definition(let definitionID):
            // The user wants to remove an override. This action "resets to default".
            // We remove the override object, and the resolver will automatically
            // start showing the library default value again.
            self.propertyOverrides.removeAll { $0.definitionID == definitionID }
            
        case .instance(let instancePropertyID):
            // The user wants to remove an instance property. This is a permanent deletion.
            self.propertyInstances.removeAll { $0.id == instancePropertyID }
        }
    }
}
