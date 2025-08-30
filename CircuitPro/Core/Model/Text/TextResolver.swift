import Foundation

struct TextResolver {
    
    /// The main resolution function that converts abstract text templates into displayable, resolved text models.
    /// This is the new, primary entry point for the resolver.
    static func resolve(for componentInstance: ComponentInstance) -> [CircuitText.Resolved] {
        // 1. --- SIMPLIFIED LOGIC ---
        // Get the symbol definition directly from the hydrated symbol instance.
        // If it's not there, we know hydration failed, and we can't proceed.
        guard let symbolDefinition = componentInstance.symbolInstance.definition else {
            return []
        }

        // 2. Call the detailed resolver.
        return self.resolve(
            definitions: symbolDefinition.textDefinitions,
            overrides: componentInstance.symbolInstance.textOverrides,
            instances: componentInstance.symbolInstance.textInstances,
            properties: componentInstance.displayedProperties,
            componentDefinition: componentInstance.definition
        )
    }

    /// The detailed resolution function that performs the string content generation.
    /// This is now a private helper, as the `resolve(for:)` function is the public API.
    private static func resolve(
        definitions: [CircuitText.Definition],
        overrides: [CircuitText.Override],
        instances: [CircuitText.Instance],
        properties: [Property.Resolved], // The resolved properties of the component
        componentDefinition: ComponentDefinition? // The definition for accessing attributes
    ) -> [CircuitText.Resolved] {

        // 1. Use the @Resolvable macro's generated resolver to get the final combined template settings.
        let resolvedTemplates = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        // 2. Post-process the templates to generate the final string content.
        return resolvedTemplates.compactMap { resolved -> CircuitText.Resolved? in
            guard resolved.isVisible, let def = componentDefinition else { return nil }
            
            var finalResolved = resolved
            
            // The logic for generating text content remains largely the same,
            // but it now uses the direct `properties` and `componentDefinition` parameters
            // instead of the old `DesignComponent`.
            switch resolved.contentSource {
                
            case .componentAttribute(let attributeSource):
                // To access attributes, we now need a simple way to look them up on the definition.
                // You can use the KeyPathable feature you already have.
                if let keyPath = ComponentDefinition._keyPath(for: attributeSource.key) {
                    let value = def[keyPath: keyPath]
                    finalResolved.text = String(describing: value)
                } else {
                    finalResolved.text = "n/a"
                }
                
            case .componentProperty(let definitionID):
                // This logic now correctly uses the pre-resolved `properties` array.
                guard let prop = properties.first(where: { $0.id == definitionID }) else {
                    finalResolved.text = "n/a"
                    break
                }
                
                var parts: [String] = []
                if resolved.displayOptions.showKey, !prop.key.label.isEmpty {
                    parts.append("\(prop.key.label):")
                }
                if resolved.displayOptions.showValue {
                    parts.append(prop.value.description)
                }
                if resolved.displayOptions.showUnit, !prop.unit.symbol.isEmpty {
                    parts.append(prop.unit.symbol)
                }
                finalResolved.text = parts.joined(separator: " ")
            }
            
            return finalResolved
        }
    }
}
