import Foundation

extension SymbolInstance {
    
    /// Updates the instance's text data based on a change made from the UI.
    /// - Parameter editedText: The `Resolved` model representing the new, desired state.
    func update(with editedText: CircuitText.Resolved) {
        switch editedText.source {
            
        case .definition(let definitionID):
            // The user modified a text derived from a definition.
            // We must create or update an override to store these changes.
            if let index = self.textOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // An override for this text already exists, so we update it.
                self.textOverrides[index].relativePosition = editedText.relativePosition
                self.textOverrides[index].font = editedText.font
                self.textOverrides[index].color = editedText.color
                self.textOverrides[index].anchor = editedText.anchor
                self.textOverrides[index].alignment = editedText.alignment
                self.textOverrides[index].cardinalRotation = editedText.cardinalRotation
                self.textOverrides[index].isVisible = editedText.isVisible
                // Per our design, we do not override the 'text' content itself for definitions.
                // The 'text' property in the override remains unused in this scenario.

            } else {
                // No override exists. We create a new one to capture the changes.
                // We provide a value for every overridable property.
                let newOverride = CircuitText.Override(
                    definitionID: definitionID,
                    text: "", // Pass an empty string to satisfy the non-optional requirement.
                    relativePosition: editedText.relativePosition,
                    font: editedText.font,
                    color: editedText.color,
                    anchor: editedText.anchor,
                    alignment: editedText.alignment,
                    cardinalRotation: editedText.cardinalRotation,
                    isVisible: editedText.isVisible
                )
                self.textOverrides.append(newOverride)
            }
            
        case .instance(let instanceID):
            // The user modified an instance-specific text. We update it directly.
            guard let index = self.textInstances.firstIndex(where: { $0.id == instanceID }) else { return }
            
            self.textInstances[index].text = editedText.text
            self.textInstances[index].relativePosition = editedText.relativePosition
            self.textInstances[index].definitionPosition = editedText.definitionPosition
            self.textInstances[index].font = editedText.font
            self.textInstances[index].color = editedText.color
            self.textInstances[index].anchor = editedText.anchor
            self.textInstances[index].alignment = editedText.alignment
            self.textInstances[index].cardinalRotation = editedText.cardinalRotation
            self.textInstances[index].isVisible = editedText.isVisible
        }
    }

    /// Adds a new ad-hoc `CircuitText.Instance` to this symbol instance.
    func add(_ newText: CircuitText.Instance) {
        self.textInstances.append(newText)
    }

    /// Removes a text element based on its resolved model.
    func remove(_ textToRemove: CircuitText.Resolved) {
        switch textToRemove.source {
            
        case .definition(let definitionID):
            // "Removing" a definition-based text means hiding it via an override.
            if let index = self.textOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // An override already exists; just mark it as invisible.
                self.textOverrides[index].isVisible = false
            } else {
                // No override exists. Create a new one whose only purpose is to hide the text.
                // We must be explicit and provide values for all properties.
                let newOverride = CircuitText.Override(
                    definitionID: definitionID,
                    text: "", // Unused, but required by the initializer.
                    isVisible: false // The sole purpose of this override.
                )
                self.textOverrides.append(newOverride)
            }
            
        case .instance(let instanceID):
            // Permanently delete instance-specific text.
            self.textInstances.removeAll { $0.id == instanceID }
        }
    }
}
