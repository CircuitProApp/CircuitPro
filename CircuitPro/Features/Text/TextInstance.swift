//
//  TextInstance.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import SwiftUI

struct TextInstance: Identifiable, Codable, Hashable, TextCore {
    var id: UUID = UUID()
    var text: String
    var relativePosition: CGPoint
    var cardinalRotation: CardinalRotation = .east
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.labelColor.cgColor
    var alignment: NSTextAlignment = .center
    
    // MARK: - Manual Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, text, relativePosition, alignment, cardinalRotation
        case fontName, fontSize, colorData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.relativePosition = try container.decode(CGPoint.self, forKey: .relativePosition)
        self.cardinalRotation = try container.decodeIfPresent(CardinalRotation.self, forKey: .cardinalRotation) ?? .east
        
        // --- THIS IS THE FIX for NSTextAlignment ---
        let alignmentRawValue = try container.decode(Int.self, forKey: .alignment)
        self.alignment = NSTextAlignment(rawValue: alignmentRawValue) ?? .center
        
        // Decode Font
        let fontName = try container.decode(String.self, forKey: .fontName)
        let fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        self.font = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)

        // Decode Color
        let colorData = try container.decode(Data.self, forKey: .colorData)
        if let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            self.color = nsColor.cgColor
        } else {
            self.color = NSColor.black.cgColor
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(relativePosition, forKey: .relativePosition)
        try container.encode(cardinalRotation, forKey: .cardinalRotation)
        
        // --- THIS IS THE FIX for NSTextAlignment ---
        try container.encode(alignment.rawValue, forKey: .alignment)

        // Encode Font
        try container.encode(font.fontName, forKey: .fontName)
        try container.encode(font.pointSize, forKey: .fontSize)

        // Encode Color
        let nsColor = NSColor(cgColor: color) ?? .black
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .colorData)
    }
}

extension TextInstance: ResolvableText {
    func resolve(
        with override: TextOverride?,
        componentName: String,
        reference: String,
        properties: [ResolvedProperty]
    ) -> ResolvedText? {
        // An instance-level text cannot be hidden by an override, and it doesn't use dynamic data.
        return ResolvedText(
            origin: .instance(instanceID: id),
            text: text,
            font: font,
            color: color,
            alignment: alignment,
            relativePosition: relativePosition,
            anchorRelativePosition: relativePosition,
            cardinalRotation: cardinalRotation
        )
    }
}
