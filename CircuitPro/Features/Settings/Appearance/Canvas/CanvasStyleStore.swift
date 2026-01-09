import Foundation

enum CanvasStyleStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static var defaultStyles: [CanvasStyle] {
        [
            CanvasStyle(
                id: UUID(uuidString: "E862CE61-9C5F-4E4D-9A38-3B7B19E0AF6E")!,
                name: "Pristine",
                backgroundHex: "#FFFFFF",
                gridHex: "#8E8E93",
                textHex: "#1C1C1E",
                markerHex: "#2C2C2E",
                crosshairHex: "#3B82F6",
                schematicSymbolHex: "#3B82F6",
                schematicPinHex: "#3B82F6",
                schematicTextHex: "#1C1C1E",
                schematicWireHex: "#3B82F6",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "5F46B6E8-6DFE-4F91-9BA4-75A2C4005D12")!,
                name: "Sandstone",
                backgroundHex: "#F4EFE6",
                gridHex: "#A49173",
                textHex: "#2D4C3E",
                markerHex: "#7F6A55",
                crosshairHex: "#A64B44",
                schematicSymbolHex: "#A64B44",
                schematicPinHex: "#A64B44",
                schematicTextHex: "#2D4C3E",
                schematicWireHex: "#A64B44",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "A6F0B663-4B4F-4A7D-9F4F-3312B3C8B983")!,
                name: "Blueprint",
                backgroundHex: "#0D1B2A",
                gridHex: "#3E5C76",
                textHex: "#E0E1DD",
                markerHex: "#98C1D9",
                crosshairHex: "#E0E1DD",
                schematicSymbolHex: "#98C1D9",
                schematicPinHex: "#98C1D9",
                schematicTextHex: "#E0E1DD",
                schematicWireHex: "#98C1D9",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "1E8B1F14-0C74-4C98-8E0E-4C6A2F1E2B64")!,
                name: "Pro",
                backgroundHex: "#1C1C1E",
                gridHex: "#636366",
                textHex: "#F2F2F7",
                markerHex: "#AEAEB2",
                crosshairHex: "#60A5FA",
                schematicSymbolHex: "#60A5FA",
                schematicPinHex: "#60A5FA",
                schematicTextHex: "#F2F2F7",
                schematicWireHex: "#60A5FA",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "33A7C5F4-8149-4158-971E-031234567890")!,
                name: "Chalkboard",
                backgroundHex: "#1B3022",
                gridHex: "#2D4B39",
                textHex: "#FCFAED",
                markerHex: "#D2B48C",
                crosshairHex: "#FFFFFF",
                schematicSymbolHex: "#FFFFFF",
                schematicPinHex: "#FFFFFF",
                schematicTextHex: "#FCFAED",
                schematicWireHex: "#FFFFFF",
                isBuiltin: true
            ),
        ]
    }

    static var defaultStylesData: String {
        guard let data = try? encoder.encode(defaultStyles) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static var defaultSelectedLightID: String {
        defaultStyles.first(where: { $0.name == "Pristine" })?.id.uuidString ?? defaultStyles.first?
            .id.uuidString ?? ""
    }

    static var defaultSelectedDarkID: String {
        defaultStyles.first(where: { $0.name == "Pro" })?.id.uuidString ?? defaultStyles.first?.id
            .uuidString ?? ""
    }

    static func loadStyles(from dataString: String) -> [CanvasStyle] {
        guard let data = dataString.data(using: .utf8),
            var styles = try? decoder.decode([CanvasStyle].self, from: data),
            !styles.isEmpty
        else { return defaultStyles }

        // Ensure all built-in default styles are present
        for defaultStyle in defaultStyles {
            if !styles.contains(where: { $0.id == defaultStyle.id }) {
                styles.append(defaultStyle)
            }
        }

        return styles
    }

    static func encodeStyles(_ styles: [CanvasStyle]) -> String {
        guard let data = try? encoder.encode(styles) else { return defaultStylesData }
        return String(decoding: data, as: UTF8.self)
    }

    static func selectedStyle(from styles: [CanvasStyle], selectedID: String) -> CanvasStyle {
        if let style = styles.first(where: { $0.id.uuidString == selectedID }) {
            return style
        }
        return styles.first ?? defaultStyles[0]
    }
}
