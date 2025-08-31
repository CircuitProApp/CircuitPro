import Foundation

struct TextResolver {
    
    /// The main resolution function.
    static func resolve(for componentInstance: ComponentInstance) -> [CircuitText.Resolved] {
        guard let symbolDefinition = componentInstance.symbolInstance.definition else {
            return []
        }
        
        return self.resolve(
            definitions: symbolDefinition.textDefinitions,
            overrides: componentInstance.symbolInstance.textOverrides,
            instances: componentInstance.symbolInstance.textInstances,
            properties: componentInstance.displayedProperties,
            componentInstance: componentInstance // Pass the full instance
        )
    }
    
    /// The detailed resolution function.
    private static func resolve(
        definitions: [CircuitText.Definition],
        overrides: [CircuitText.Override],
        instances: [CircuitText.Instance],
        properties: [Property.Resolved],
        componentInstance: ComponentInstance
    ) -> [CircuitText.Resolved] {
        
        let resolvedTemplates = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        return resolvedTemplates.compactMap { resolved -> CircuitText.Resolved? in
            guard resolved.isVisible, let def = componentInstance.definition else { return nil }
            
            var finalResolved = resolved
            
            switch resolved.contentSource {
                
            case .componentName:
                finalResolved.text = def.name
                
            case .componentReferenceDesignator:
                finalResolved.text = def.referenceDesignatorPrefix + componentInstance.referenceDesignatorIndex.description
                
            case .componentProperty(let definitionID):
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
