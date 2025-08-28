import Foundation

extension TextSource {
    
    /// Resolves the text source into a final display string based on the provided component data.
    func resolveString(
        with displayOptions: TextDisplayOptions,
        componentName: String,
        reference: String,
        properties: [Property.Resolved]
    ) -> String {
        switch self {
        case .reference:
            return reference
            
        case .componentName:
            return componentName
            
        case .property(let definitionID):
            guard let prop = properties.first(where: {
                if case .definition(let defID) = $0.source { return defID == definitionID }
                return false
            }) else {
                return "n/a"
            }

            var parts: [String] = []
            if displayOptions.showKey {
                // You might want to add a check here to not show a key if it's empty.
                if !prop.key.label.isEmpty {
                    parts.append("\(prop.key.label):")
                }
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
