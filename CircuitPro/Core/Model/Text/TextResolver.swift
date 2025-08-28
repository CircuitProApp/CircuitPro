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

        // 1. Use the macro's resolver to get the final resolved templates.
        let resolvedTemplates = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        // 2. Post-process the templates to generate the final string content.
        return resolvedTemplates.compactMap { resolved -> CircuitText.Resolved? in
            // First, filter out any text that has been explicitly hidden.
            guard resolved.isVisible else { return nil }
            
            // Create a mutable copy to update its `text` property.
            var finalResolved = resolved
            
            // With the new TextSource model, every source is dynamic. We simply
            // resolve its content and assign it to the `text` property.
            finalResolved.text = resolved.contentSource.resolveString(
                with: resolved.displayOptions,
                componentName: componentName,
                reference: reference,
                properties: properties
            )

            // Return the updated struct with the final text content.
            return finalResolved
        }
    }
}
