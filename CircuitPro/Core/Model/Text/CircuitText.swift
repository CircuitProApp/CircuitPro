//
//  CircuitText.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import ResolvableMacro

@Resolvable
struct CircuitText {
    // MARK: - Content Properties
    
    /// The source that defines the text's string content (e.g., static, dynamic).
    var contentSource: TextSource = .static("")
    
    /// For instances, this provides the static text content. For definitions, this is unused.
    @Overridable var text: String = ""

    /// Formatting options for dynamically generated text.
    var displayOptions: TextDisplayOptions = .default
    
    // MARK: - Overridable Style & Position Properties
    
    /// The current position, which can be overridden.
    @Overridable var relativePosition: CGPoint
    
    /// The original position from the definition, used for drawing anchor lines. This is not overridable.
    var definitionPosition: CGPoint
    
    /// The font, stored as a custom Codable `SDFont` struct.
    @Overridable var font: SDFont = .init(font: .systemFont(ofSize: 12))
    
    /// The color, stored using your `SDColor` struct.
    @Overridable var color: SDColor = .init(color: .init(nsColor: .labelColor))
    
    /// The text's anchor point.
    @Overridable var anchor: TextAnchor = .bottomLeft
    
    /// The text alignment, stored as a custom Codable `SDAlignment` enum.
    @Overridable var alignment: SDAlignment = .center
    
    /// The rotation of the text.
    @Overridable var cardinalRotation: CardinalRotation = .east
    
    /// The visibility of the text. Can be set to `false` in an override to hide it.
    @Overridable var isVisible: Bool = true
}
