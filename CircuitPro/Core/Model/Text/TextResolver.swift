import Foundation

struct TextResolver {
    
    /// The main resolution function that converts abstract text templates into displayable, resolved text models.
    static func resolve(
        definitions: [CircuitText.Definition],
        overrides: [CircuitText.Override],
        instances: [CircuitText.Instance],
        // The entire context is now passed in this single, smart object.
        for component: DesignComponent
    ) -> [CircuitText.Resolved] {

        // 1. Use the macro's resolver to get the final combined template settings.
        let resolvedTemplates = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        // 2. Post-process the templates to generate the final string content.
        return resolvedTemplates.compactMap { resolved -> CircuitText.Resolved? in
            guard resolved.isVisible else { return nil }
            
            var finalResolved = resolved
            
            // --- THIS IS THE CORRECTED LOGIC ---
            // It now correctly handles the final, type-safe TextSource enum.
            switch resolved.contentSource {
                
            case .componentAttribute(let attributeSource):
                // We access the string key from the safe `AttributeSource` struct
                // and use the component's dynamic member lookup.
                finalResolved.text = component[attributeSource]
                
            case .componentProperty(let definitionID):
                // This logic correctly uses the component's displayedProperties.
                guard let prop = component.displayedProperties.first(where: { $0.id == definitionID }) else {
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
