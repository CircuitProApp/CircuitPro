import AppKit
import SwiftUI

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

extension NSColor {
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
            red = CGFloat((value & 0xFF00_0000) >> 24) / 255.0
            green = CGFloat((value & 0x00FF_0000) >> 16) / 255.0
            blue = CGFloat((value & 0x0000_FF00) >> 8) / 255.0
            alpha = CGFloat(value & 0x0000_00FF) / 255.0
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
