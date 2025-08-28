import Foundation

extension TextSource {
    
    /// Resolves the text source into a final display string using a `DesignComponent` as the data context.
    /// - Parameters:
    ///   - component: The `DesignComponent` proxy, which provides access to all necessary data.
    ///   - displayOptions: Formatting options, used primarily for `componentProperty` sources.
    /// - Returns: The final, human-readable string.
    func resolveString(
        for component: DesignComponent,
        with displayOptions: TextDisplayOptions
    ) -> String {
        
        switch self {
        case .componentAttribute(let attributeSource):
            // The old ".reference" and ".componentName" cases are now handled by this.
            // For example: .componentAttribute(key: "referenceDesignator") or .componentAttribute(key: "name")
            // We use the dynamic member lookup feature of DesignComponent for a clean, direct access.
            return component[attributeSource]
            
        case .componentProperty(let definitionID):
            // We get the final list of properties directly from the component.
            guard let prop = component.displayedProperties.first(where: { $0.id == definitionID }) else {
                return "n/a"
            }

            // This logic for assembling parts is still relevant and correct.
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
