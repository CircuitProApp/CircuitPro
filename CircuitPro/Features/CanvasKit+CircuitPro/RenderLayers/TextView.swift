import AppKit

struct TextView: CKView {
    @CKContext var context
    let text: CircuitText.Definition
    
    var textColor: CGColor {
        context.environment.schematicTheme.textColor
    }

    var showHalo: Bool {
        context.highlightedItemIDs.contains(text.id)
    }
    
    private func resolvedDefinitionText(_ text: CircuitText.Definition) -> String {
        if let resolver = context.environment.definitionTextResolver {
            return resolver(text)
        }
        return displayText(for: text.content)
    }

    private func displayText(for content: CircuitTextContent) -> String {
        switch content {
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

    var body: some CKView {
        CKText(resolvedDefinitionText(text), font: text.font.nsFont, anchor: text.anchor)
            .position(text.relativePosition)
            .rotation(text.cardinalRotation.radians)
            .fill(textColor)
            .halo(showHalo ? textColor.copy(alpha: 0.3) ?? .clear : .clear, width: 5)
    }
}
