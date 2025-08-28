import Foundation

extension SymbolInstance {
    
    /// Updates the instance's text data based on a change made from the UI.
    /// - Parameter editedText: The `Resolved` model representing the new, desired state.
    func update(with editedText: CircuitText.Resolved) {
        switch editedText.source {
            
        case .definition(let definitionID):
            if let index = self.textOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // An override for this text already exists, so we update it.
                
                // --- FIX: Add this line to save the anchor position to the existing override. ---
                self.textOverrides[index].anchorPosition = editedText.anchorPosition
                
                self.textOverrides[index].relativePosition = editedText.relativePosition
                self.textOverrides[index].font = editedText.font
                self.textOverrides[index].color = editedText.color
                self.textOverrides[index].anchor = editedText.anchor
                self.textOverrides[index].alignment = editedText.alignment
                self.textOverrides[index].cardinalRotation = editedText.cardinalRotation
                self.textOverrides[index].isVisible = editedText.isVisible

            } else {
                // No override exists. We create a new one to capture the changes.
                let newOverride = CircuitText.Override(
                    definitionID: definitionID,
                    text: "",
                    relativePosition: editedText.relativePosition,
                    // --- FIX: Add this parameter to the initializer call. ---
                    anchorPosition: editedText.anchorPosition,
                    
              
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
            // This part is correct.
            guard let index = self.textInstances.firstIndex(where: { $0.id == instanceID }) else { return }
            
            self.textInstances[index].text = editedText.text
            self.textInstances[index].relativePosition = editedText.relativePosition
            self.textInstances[index].anchorPosition = editedText.anchorPosition
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
