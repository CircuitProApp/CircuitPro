import Foundation

extension TextSource {
    func resolveString(
        with displayOptions: TextDisplayOptions,
        componentName: String,
        reference: String,
        properties: [Property.Resolved]
    ) -> String {
        switch self {
        case .static(let text):
            return text
        case .dynamic(let dynamicSource):
            switch dynamicSource {
            case .componentName:
                return componentName
            case .reference:
                return reference
            case .property(let definitionID):
                guard let prop = properties.first(where: {
                    if case .definition(let defID) = $0.source { return defID == definitionID }
                    return false
                }) else { return "n/a" }

                var parts: [String] = []
                if displayOptions.showKey {
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
}
