// Features/Property/ComponentInstance+PropertyManagement.swift

import Foundation

extension ComponentInstance {
    
    /// Updates the instance's properties based on a change to a resolved property.
    func update(with editedProperty: Property.Resolved) {
        switch editedProperty.source {
        case .definition(let definitionID):
            // The logic here is to find an existing override and update its value.
            if let index = self.propertyOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // Because `value` is the only @Overridable property, it's the only one we need to update.
                self.propertyOverrides[index].value = editedProperty.value
            } else {
                // If no override exists, create a new one. The macro ensures the Override
                // struct only contains the overridable properties.
                let newOverride = Property.Override(definitionID: definitionID, value: editedProperty.value)
                self.propertyOverrides.append(newOverride)
            }
            
        case .instance(let instancePropertyID):
            // For ad-hoc properties, find the instance and update its values directly.
            if let index = self.propertyInstances.firstIndex(where: { $0.id == instancePropertyID }) {
                self.propertyInstances[index].value = editedProperty.value
                self.propertyInstances[index].key = editedProperty.key // you may want to allow editing other fields too
            }
        }
    }

    /// Adds a new, user-created property directly to this instance.
    func add(_ newProperty: Property.Instance) {
        self.propertyInstances.append(newProperty)
    }

    /// Removes a property from this instance.
    func remove(_ propertyToRemove: Property.Resolved) {
        switch propertyToRemove.source {
        case .definition(let definitionID):
            // To "remove" a definition-based property, we just remove its override,
            // which causes it to revert to the default value.
            self.propertyOverrides.removeAll { $0.definitionID == definitionID }
            
        case .instance(let instancePropertyID):
            // An ad-hoc instance property can be removed entirely.
            self.propertyInstances.removeAll { $0.id == instancePropertyID }
        }
    }
}
