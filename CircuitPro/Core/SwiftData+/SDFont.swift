//
//  SDFont.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct SDFont: Codable, Equatable, Hashable {
    var name: String
    var size: CGFloat

    init(font: NSFont) {
        self.name = font.fontName
        self.size = font.pointSize
    }

    var nsFont: NSFont {
        NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}
