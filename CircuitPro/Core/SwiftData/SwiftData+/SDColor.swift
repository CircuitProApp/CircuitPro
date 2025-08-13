//
//  SDColor.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import AppKit

struct SDColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            self.red = 1.0
            self.green = 0.0
            self.blue = 0.0
            self.alpha = 1.0
            return
        }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0 // swiftlint:disable:this identifier_name

        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    // MARK: - SwiftUI Color
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    // MARK: - AppKit NSColor
    var nsColor: NSColor {
        NSColor(color)
    }

    // MARK: - Core Graphics CGColor
    var cgColor: CGColor {
        nsColor.cgColor
    }
}
