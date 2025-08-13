//
//  TextDefinition.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import SwiftUI

struct TextDefinition: Identifiable, Codable, Hashable, TextCore {
    var id: UUID = UUID()
    var source: TextSource
    var relativePosition: CGPoint
    var cardinalRotation: CardinalRotation = .east
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.black.cgColor
    var alignment: NSTextAlignment = .center
    var anchor: TextAnchor = .bottomLeft
    var displayOptions: TextDisplayOptions = .default
    
    init (
        source: TextSource,
        relativePosition: CGPoint,
        cardinalRotation: CardinalRotation = .east,
        displayOptions: TextDisplayOptions = .default,
        anchor: TextAnchor = .bottomLeft
    ) {
        self.source = source
        self.relativePosition = relativePosition
        self.cardinalRotation = cardinalRotation
        self.displayOptions = displayOptions
        self.anchor = anchor
    }


    // MARK: - Manual Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, source, displayOptions, relativePosition, alignment, cardinalRotation, anchor
        case fontName, fontSize, colorData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.source = try container.decode(TextSource.self, forKey: .source)
        self.relativePosition = try container.decode(CGPoint.self, forKey: .relativePosition)
        
        self.cardinalRotation = try container.decodeIfPresent(CardinalRotation.self, forKey: .cardinalRotation) ?? .east
        self.displayOptions = try container.decodeIfPresent(TextDisplayOptions.self, forKey: .displayOptions) ?? .default
        
        let alignmentRawValue = try container.decode(Int.self, forKey: .alignment)
        self.alignment = NSTextAlignment(rawValue: alignmentRawValue) ?? .center
        
        self.anchor = try container.decode(TextAnchor.self, forKey: .anchor)
        
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
        try container.encode(source, forKey: .source)
        try container.encode(relativePosition, forKey: .relativePosition)
        try container.encode(alignment.rawValue, forKey: .alignment)
        try container.encode(cardinalRotation, forKey: .cardinalRotation)
        try container.encode(displayOptions, forKey: .displayOptions)

        // Encode Font
        try container.encode(font.fontName, forKey: .fontName)
        try container.encode(font.pointSize, forKey: .fontSize)
        
        try container.encode(anchor, forKey: .anchor)

        // Encode Color
        let nsColor = NSColor(cgColor: color) ?? .black
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .colorData)
    }
}

extension TextDefinition: ResolvableText {
    func resolve(
        with override: TextOverride?,
        componentName: String,
        reference: String,
        properties: [ResolvedProperty]
    ) -> ResolvedText? {
        if let override, !override.isVisible { return nil }

        let resolvedString = source.resolveString(
            with: displayOptions,
            componentName: componentName,
            reference: reference,
            properties: properties
        )

        return ResolvedText(
            origin: .definition(definitionID: id),
            text: resolvedString,
            font: font,
            color: color,
            alignment: alignment,
            anchor: anchor,
            relativePosition: override?.relativePositionOverride ?? relativePosition,
            anchorRelativePosition: relativePosition,
            cardinalRotation: cardinalRotation
        )
    }
}


