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

        // 1. Use the macro's resolver. This part is correct.
        let resolvedFromMacro = CircuitText.Resolver.resolve(
            definitions: definitions,
            overrides: overrides,
            instances: instances
        )
        
        // 2. Post-process the results.
        return resolvedFromMacro.compactMap { resolved -> CircuitText.Resolved? in
            // Filter out texts that are explicitly hidden. This is correct.
            guard resolved.isVisible else { return nil }
            
            var finalResolved = resolved
            
            // --- THIS IS THE FIX ---
            // If the content source is DYNAMIC, we MUST generate the string content,
            // regardless of whether it's from a definition or an instance.
            if case .dynamic = finalResolved.contentSource {
                finalResolved.text = finalResolved.contentSource.resolveString(
                    with: finalResolved.displayOptions,
                    componentName: componentName,
                    reference: reference,
                    properties: properties
                )
            }
            // If the content source is .static, the text from the macro is already correct.
            
            return finalResolved
        }
    }
}
