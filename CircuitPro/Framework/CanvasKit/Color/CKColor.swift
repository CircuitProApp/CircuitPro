import AppKit
import SwiftUI

struct CKColor {
    private let baseColor: NSColor

    init(_ color: NSColor) {
        self.baseColor = color
    }

    init(_ color: CGColor) {
        self.baseColor = NSColor(cgColor: color) ?? NSColor.black
    }

    init(_ color: Color) {
        self.baseColor = NSColor(color)
    }

    init(_ color: SDColor) {
        self.baseColor = color.nsColor
    }

    var nsColor: NSColor { baseColor }
    var cgColor: CGColor { baseColor.cgColor }
    var color: Color { Color(baseColor) }

    func opacity(_ value: CGFloat) -> CKColor {
        CKColor(baseColor.withAlphaComponent(value))
    }
    
    func haloOpacity() -> CKColor {
        opacity(0.35)
    }
}

extension CKColor {
    static let clear = CKColor(NSColor.clear)
    static let black = CKColor(NSColor.black)
    static let white = CKColor(NSColor.white)
    static let red = CKColor(NSColor.systemRed)
    static let green = CKColor(NSColor.systemGreen)
    static let blue = CKColor(NSColor.systemBlue)
    static let gray = CKColor(NSColor.systemGray)
    static let label = CKColor(NSColor.labelColor)
}
