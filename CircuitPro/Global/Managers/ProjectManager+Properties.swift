//
//  ProjectManager+Properties.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/25/25.
//

import Foundation

extension ProjectManager {

    /// Updates the value of a property for a specific component instance.
    /// This function correctly handles updating either an override or an ad-hoc property
    /// based on the source of the `DisplayedProperty`.
    ///
    /// - Parameters:
    ///   - instanceID: The UUID of the `ComponentInstance` to modify.
    ///   - updatedProperty: The `DisplayedProperty` containing the new value and source info.
    func updateProperty(forInstanceID instanceID: UUID, with updatedProperty: DisplayedProperty) {
        // 1. Find the specific component instance we need to modify.
        guard let instance = componentInstances.first(where: { $0.id == instanceID }) else {
            print("Error: Could not find ComponentInstance with ID \(instanceID)")
            return
        }

        // 2. Determine if we are updating a library-defined property or an ad-hoc one.
        if let definitionID = updatedProperty.sourceDefinitionID {
            // This is an OVERRIDE of a defined property.
            
            // 2.1 Check if an override already exists for this definition.
            if let overrideIndex = instance.propertyOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // If it exists, just update its value.
                instance.propertyOverrides[overrideIndex].value = updatedProperty.value
            } else {
                // If it doesn't exist, this is the first time the user is overriding it.
                // Create a new override and add it to the list.
                let newOverride = PropertyOverride(definitionID: definitionID, value: updatedProperty.value)
                instance.propertyOverrides.append(newOverride)
            }
        } else {
            // This is an AD-HOC property. It must already exist in the ad-hoc list to be updated.
            
            // 2.2 Find the ad-hoc property by its unique ID.
            if let adHocIndex = instance.adHocProperties.firstIndex(where: { $0.id == updatedProperty.id }) {
                // Update its value.
                instance.adHocProperties[adHocIndex].value = updatedProperty.value
            } else {
                print("Logic Error: Tried to update an ad-hoc property that doesn't exist. ID: \(updatedProperty.id)")
            }
        }
    }

    /// Adds a new, user-created ad-hoc property to a specific component instance.
    ///
    /// - Parameters:
    ///   - newProperty: The fully-formed ad-hoc property to add.
    ///   - toInstanceID: The UUID of the `ComponentInstance` that will receive the new property.
    func addProperty(_ newProperty: InstanceAdHocProperty, toInstanceID: UUID) {
        guard let instance = componentInstances.first(where: { $0.id == toInstanceID }) else {
            print("Error: Could not find ComponentInstance with ID \(toInstanceID)")
            return
        }

        instance.adHocProperties.append(newProperty)
    }

    /// Removes a property from a component instance.
    /// - If the property is an override, this effectively "resets it to default".
    /// - If the property is ad-hoc, it is deleted permanently.
    ///
    /// - Parameters:
    ///   - propertyToRemove: The `DisplayedProperty` that the user wants to remove.
    ///   - fromInstanceID: The UUID of the `ComponentInstance` to modify.
    func removeProperty(_ propertyToRemove: DisplayedProperty, fromInstanceID: UUID) {
        guard let instance = componentInstances.first(where: { $0.id == fromInstanceID }) else {
            print("Error: Could not find ComponentInstance with ID \(fromInstanceID)")
            return
        }
        
        if let definitionID = propertyToRemove.sourceDefinitionID {
            // The user is removing an OVERRIDE. This means "Reset to Default".
            // We just need to remove the override object from the array.
            instance.propertyOverrides.removeAll { $0.definitionID == definitionID }
        } else {
            // The user is removing an AD-HOC property. This is a permanent deletion.
            instance.adHocProperties.removeAll { $0.id == propertyToRemove.id }
        }
    }
}
