import Foundation

extension SymbolInstance {
    
    /// Updates the instance's text properties based on a change made to a `ResolvedText` from the UI.
    func update(with editedText: ResolvedText) {
        switch editedText.origin {
        case .definition(let definitionID):
            // The user modified a text derived from a definition. Create or update an override.
            if let index = self.textOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                // Update existing override.
                self.textOverrides[index].relativePositionOverride = editedText.relativePosition
                // Here, you could also handle `textOverride`, `isVisible`, etc.
            } else {
                // Create a new override.
                let newOverride = TextOverride(definitionID: definitionID, relativePositionOverride: editedText.relativePosition)
                self.textOverrides.append(newOverride)
            }
            
        case .instance(let instanceID):
            // The user modified an instance-specific text.
            if let index = self.textInstances.firstIndex(where: { $0.id == instanceID }) {
                self.textInstances[index].relativePosition = editedText.relativePosition
                self.textInstances[index].cardinalRotation = editedText.cardinalRotation
                self.textInstances[index].text = editedText.text
            }
        }
    }

    /// Adds a new `TextInstance` to this symbol instance.
    func add(_ newText: TextInstance) {
        self.textInstances.append(newText)
    }

    /// Removes a text override or deletes a text instance.
    func remove(_ textToRemove: ResolvedText) {
        switch textToRemove.origin {
        case .definition(let definitionID):
            // "Removing" a definition-based text means making it invisible via an override.
            // If we just removed the override, it would reappear.
            if let index = self.textOverrides.firstIndex(where: { $0.definitionID == definitionID }) {
                self.textOverrides[index].isVisible = false
            } else {
                let newOverride = TextOverride(definitionID: definitionID, isVisible: false)
                self.textOverrides.append(newOverride)
            }
        case .instance(let instanceID):
            // Removing an instance text is a permanent deletion.
            self.textInstances.removeAll { $0.id == instanceID }
        }
    }
}
