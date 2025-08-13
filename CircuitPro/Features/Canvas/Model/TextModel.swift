//
//  TextModel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//


import AppKit
import SwiftUI

/// The underlying data model for a text element.
struct TextModel: Identifiable {
    let id: UUID
    var text: String
    var position: CGPoint
    var anchor: TextAnchor
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.black.cgColor
    var alignment: NSTextAlignment = .left

    // Keep the cardinal rotation for snapping behavior.
    var cardinalRotation: CardinalRotation = .east
}

extension TextModel: Transformable {
    var rotation: CGFloat {
        get { cardinalRotation.radians }
        set { cardinalRotation = .closestWithDiagonals(to: newValue) }
    }
}

extension TextModel {
    /// Generates the raw, un-transformed path for the text glyphs.
    /// The path's origin is the text's baseline start point.
    func makeTextPath() -> CGPath {
        return TextUtilities.path(for: text, font: font)
    }
}
