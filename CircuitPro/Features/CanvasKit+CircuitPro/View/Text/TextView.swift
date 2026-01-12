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
    
    var body: some CKView {
        let display = displayText(
            for: text,
            resolver: context.environment.definitionTextResolver
        )
        CKText(display, font: text.font.nsFont, anchor: text.anchor)
            .position(text.relativePosition)
            .rotation(text.cardinalRotation.radians)
            .fill(textColor)
            .halo(showHalo ? textColor.copy(alpha: 0.3) ?? .clear : .clear, width: 5)
    }
}
