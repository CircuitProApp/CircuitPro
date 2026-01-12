import AppKit

func displayText(
    for definition: CircuitText.Definition,
    resolver: DefinitionTextResolver?
) -> String {
    if let resolver {
        return resolver(definition)
    }
    switch definition.content {
    case .static(let value):
        return value
    case .componentName:
        return "Name"
    case .componentReferenceDesignator:
        return "REF?"
    case .componentProperty(_, _):
        return ""
    }
}
