import Foundation

extension TextSource {
    
    /// --- CORRECTED ---
    /// Resolves the text source into a final display string using a `ComponentInstance` as the data context.
    /// - Parameters:
    ///   - component: The hydrated `ComponentInstance`, which provides access to all necessary data.
    ///   - displayOptions: Formatting options, used primarily for `componentProperty` sources.
    /// - Returns: The final, human-readable string.
    func resolveString(
        for component: ComponentInstance, // Changed from DesignComponent
        with displayOptions: TextDisplayOptions
    ) -> String {
        
        // Safely unwrap the definition from the instance. If it's missing,
        // we can't resolve the text, so we return an error string.
        guard let definition = component.definition else {
            return "ERR: Missing Definition"
        }
        
        switch self {
        case .componentAttribute(let attributeSource):
            // We now access attributes by using the KeyPathable feature
            // directly on the `ComponentDefinition` object.
            
            // A special case for the reference designator, which is a combination
            // of a definition property and an instance property.
            if attributeSource.key == "referenceDesignatorPrefix" {
                return "\(definition.referenceDesignatorPrefix)\(component.referenceDesignatorIndex)"
            }
            
            // For all other attributes, look them up on the definition.
            if let keyPath = ComponentDefinition._keyPath(for: attributeSource.key) {
                let value = definition[keyPath: keyPath]
                return String(describing: value)
            } else {
                return "n/a"
            }
            
        case .componentProperty(let definitionID):
            // We get the final list of properties by calling the helper
            // `displayedProperties` that we previously added to `ComponentInstance`.
            guard let prop = component.displayedProperties.first(where: { $0.id == definitionID }) else {
                return "n/a"
            }

            // This logic for assembling parts remains the same.
            var parts: [String] = []
            if displayOptions.showKey, !prop.key.label.isEmpty {
                parts.append("\(prop.key.label):")
            }
            if displayOptions.showValue {
                parts.append(prop.value.description)
            }
            if displayOptions.showUnit, !prop.unit.symbol.isEmpty {
                parts.append(prop.unit.symbol)
            }
            return parts.joined(separator: " ")
        }
    }
}
