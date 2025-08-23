//
//  Features/Property/ComponentInstance+PropertyManagement.swift
//  CircuitPro
//

import Foundation

extension ComponentInstance {
    
    /// Finds the index of an existing override for a given definition ID,
    /// or creates a new, empty override and returns its index.
    /// - Parameter definitionID: The UUID of the property definition to find or create an override for.
    /// - Returns: The index of the corresponding override in the `propertyOverrides` array.
    private func getOrCreateOverrideIndex(for definitionID: UUID) -> Int {
        if let index = self.propertyOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
            return index
        } else {
            let newOverride = Property.Override(definitionID: definitionID)
            self.propertyOverrides.append(newOverride)
            return self.propertyOverrides.count - 1
        }
    }

    /// Updates the `value` for a property identified by its definition ID.
    ///
    /// This is the new, preferred way to handle UI edits for a property's main value.
    /// It will create a new override object if one doesn't already exist.
    ///
    /// - Parameters:
    ///   - definitionID: The UUID of the `Property.Definition` being overridden.
    ///   - value: The new `PropertyValue` to set.
    func update(definitionID: UUID, value: PropertyValue) {
        let index = getOrCreateOverrideIndex(for: definitionID)
        self.propertyOverrides[index].value = value
    }

    /// Updates the `unit_prefix` for a property identified by its definition ID.
    ///
    /// This is the new, preferred way to handle UI edits for a property's unit prefix.
    /// It will create a new override object if one doesn't already exist.
    ///
    /// - Parameters:
    ///   - definitionID: The UUID of the `Property.Definition` being overridden.
    ///   - prefix: The new `SIPrefix` to set. This can be `nil`.
    func update(definitionID: UUID, prefix: SIPrefix?) {
        let index = getOrCreateOverrideIndex(for: definitionID)
        self.propertyOverrides[index].unit_prefix = prefix
    }

    /// Adds a new, user-created property directly to this instance. This is for ad-hoc
    /// properties that do not originate from a library definition.
    func add(_ newProperty: Property.Instance) {
        self.propertyInstances.append(newProperty)
    }

    /// Removes a property override or an entire instance property.
    ///
    /// - Parameter propertyToRemove: The resolved property to remove. Based on its `source`,
    ///   this will either remove an override (reverting the property to its default)
    ///   or delete an ad-hoc instance property entirely.
    func remove(_ propertyToRemove: Property.Resolved) {
        switch propertyToRemove.source {
        case .definition(let definitionID):
            // To "remove" a definition-based property, we just remove its override,
            // which causes it to revert to the default value from the definition.
            self.propertyOverrides.removeAll { $0.definitionID == definitionID }
            
        case .instance(let instancePropertyID):
            // An ad-hoc instance property can be removed entirely from the instance.
            self.propertyInstances.removeAll { $0.id == instancePropertyID }
        }
    }
}
