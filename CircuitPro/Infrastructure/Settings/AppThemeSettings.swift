//
//  AppThemeSettings.swift
//  CircuitPro
//
//  Created by Codex on 9/21/25.
//

import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppThemeKeys {
    static let appearance = "app.appearance"
    static let canvasStyleList = "canvas.style.list"
    static let canvasStyleSelectedLight = "canvas.style.selected.light"
    static let canvasStyleSelectedDark = "canvas.style.selected.dark"
}

struct CanvasStyle: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var backgroundHex: String
    var gridHex: String
    var textHex: String
    var markerHex: String
    var isBuiltin: Bool
}

enum CanvasStyleStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static var defaultStyles: [CanvasStyle] {
        [
            CanvasStyle(
                id: UUID(uuidString: "E862CE61-9C5F-4E4D-9A38-3B7B19E0AF6E")!,
                name: "Light",
                backgroundHex: "#FFFFFF",
                gridHex: "#8E8E93",
                textHex: "#1C1C1E",
                markerHex: "#2C2C2E",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "5F46B6E8-6DFE-4F91-9BA4-75A2C4005D12")!,
                name: "Sandstone",
                backgroundHex: "#F4EFE6",
                gridHex: "#C4B8A3",
                textHex: "#3E3428",
                markerHex: "#7F6A55",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "A6F0B663-4B4F-4A7D-9F4F-3312B3C8B983")!,
                name: "Blueprint",
                backgroundHex: "#0D1B2A",
                gridHex: "#3E5C76",
                textHex: "#E0E1DD",
                markerHex: "#98C1D9",
                isBuiltin: true
            ),
            CanvasStyle(
                id: UUID(uuidString: "1E8B1F14-0C74-4C98-8E0E-4C6A2F1E2B64")!,
                name: "Dark",
                backgroundHex: "#1C1C1E",
                gridHex: "#636366",
                textHex: "#F2F2F7",
                markerHex: "#AEAEB2",
                isBuiltin: true
            )
        ]
    }

    static var defaultStylesData: String {
        guard let data = try? encoder.encode(defaultStyles) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static var defaultSelectedLightID: String {
        defaultStyles.first(where: { $0.name == "Light" })?.id.uuidString ?? defaultStyles.first?.id.uuidString ?? ""
    }

    static var defaultSelectedDarkID: String {
        defaultStyles.first(where: { $0.name == "Dark" })?.id.uuidString ?? defaultStyles.first?.id.uuidString ?? ""
    }

    static func loadStyles(from dataString: String) -> [CanvasStyle] {
        guard let data = dataString.data(using: .utf8),
              let styles = try? decoder.decode([CanvasStyle].self, from: data),
              !styles.isEmpty
        else { return defaultStyles }
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

struct CanvasThemeSettings {
    static func makeTheme(from style: CanvasStyle) -> CanvasTheme {
        CanvasTheme(
            backgroundColor: NSColor(hex: style.backgroundHex)?.cgColor ?? NSColor.white.cgColor,
            gridPrimaryColor: NSColor(hex: style.gridHex)?.cgColor ?? NSColor.gray.cgColor,
            textColor: NSColor(hex: style.textHex)?.cgColor ?? NSColor.labelColor.cgColor,
            sheetMarkerColor: NSColor(hex: style.markerHex)?.cgColor ?? NSColor.gray.cgColor
        )
    }
}

extension Color {
    init(hex: String) {
        if let color = NSColor(hex: hex) {
            self = Color(color)
        } else {
            self = .white
        }
    }

    func toHexRGBA() -> String {
        NSColor(self).toHexRGBA()
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        guard let rgba = RGBAColor(hex: hex) else { return nil }
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }

    func toHexRGBA() -> String {
        let color = usingColorSpace(.sRGB) ?? self
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBAColor(red: red, green: green, blue: blue, alpha: alpha).hexString
    }
}

private struct RGBAColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count == 6 || trimmed.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&value) else { return nil }

        if trimmed.count == 6 {
            red = CGFloat((value & 0xFF0000) >> 16) / 255.0
            green = CGFloat((value & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(value & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            red = CGFloat((value & 0xFF000000) >> 24) / 255.0
            green = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(value & 0x000000FF) / 255.0
        }
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var hexString: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        )
    }
}
