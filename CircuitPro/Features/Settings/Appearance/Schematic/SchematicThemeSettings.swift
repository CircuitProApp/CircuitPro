import AppKit

struct SchematicThemeSettings {
    static func makeTheme(from style: CanvasStyle) -> SchematicTheme {
        SchematicTheme(
            symbolColor: NSColor(hex: style.schematicSymbolHex)?.cgColor ?? NSColor.labelColor.cgColor,
            pinColor: NSColor(hex: style.schematicPinHex)?.cgColor ?? NSColor.systemBlue.cgColor,
            textColor: NSColor(hex: style.schematicTextHex)?.cgColor ?? NSColor.labelColor.cgColor,
            wireColor: NSColor(hex: style.schematicWireHex)?.cgColor ?? NSColor.systemBlue.cgColor
        )
    }
}
