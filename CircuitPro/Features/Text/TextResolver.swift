import Foundation

struct TextResolver {
    static func resolve(
        definitions: [CircuitText.Definition],
        overrides: [CircuitText.Override],
        instances: [CircuitText.Instance],
        componentName: String,
        reference: String,
        properties: [Property.Resolved]
    ) -> [CircuitText.Resolved] {

        // 1. Use the macro's generated resolver to get the base resolved models.
        let resolvedFromMacro = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        // 2. Post-process the resolved models to apply domain-specific logic.
        return resolvedFromMacro.compactMap { resolved -> CircuitText.Resolved? in
            // Filter out any text that has been hidden via an override.
            guard resolved.isVisible else { return nil }
            
            var finalResolved = resolved
            
            // Decide if we need to generate the text string dynamically.
            // We switch on the macro's `source` property to check the origin.
            switch finalResolved.source {
            case .definition:
                // It's from a definition, so we must generate its string content now.
                // THE FIX: Call `resolveString` on the `contentSource` property, which
                // is of type `TextSource` and has the method we need.
                finalResolved.text = resolved.contentSource.resolveString(
                    with: resolved.displayOptions,
                    componentName: componentName,
                    reference: reference,
                    properties: properties
                )
    
            case .instance:
                // It's an ad-hoc instance. The `resolved.text` property already holds
                // the correct static text from the `CircuitText.Instance` data.
                // No further action is needed.
                break
            }
            
            return finalResolved
        }
    }
}
