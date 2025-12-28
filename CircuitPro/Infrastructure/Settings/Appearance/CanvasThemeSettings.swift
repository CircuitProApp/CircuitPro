import AppKit

struct CanvasThemeSettings {
    static func makeTheme(from style: CanvasStyle) -> CanvasTheme {
        CanvasTheme(
            backgroundColor: NSColor(hex: style.backgroundHex)?.cgColor ?? NSColor.white.cgColor,
            gridPrimaryColor: NSColor(hex: style.gridHex)?.cgColor ?? NSColor.gray.cgColor,
            textColor: NSColor(hex: style.textHex)?.cgColor ?? NSColor.labelColor.cgColor,
            sheetMarkerColor: NSColor(hex: style.markerHex)?.cgColor ?? NSColor.gray.cgColor,
            crosshairColor: NSColor(hex: style.crosshairHex)?.cgColor ?? NSColor.systemBlue.cgColor
        )
    }
}
