//
//  AnchoredTextDefinition.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import SwiftUI

struct AnchoredTextDefinition: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var defaultText: String
    var relativePosition: CGPoint
    var font: NSFont = .systemFont(ofSize: 12)
    var color: CGColor = NSColor.black.cgColor
    var alignment: NSTextAlignment = .center
    
    init (
        defaultText: String,
        relativePosition: CGPoint
    ) {
        self.defaultText = defaultText
        self.relativePosition = relativePosition
    }

    // MARK: - Manual Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case id, defaultText, relativePosition, alignment
        case fontName, fontSize, colorData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.defaultText = try container.decode(String.self, forKey: .defaultText)
        self.relativePosition = try container.decode(CGPoint.self, forKey: .relativePosition)
        
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
        try container.encode(defaultText, forKey: .defaultText)
        try container.encode(relativePosition, forKey: .relativePosition)

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
