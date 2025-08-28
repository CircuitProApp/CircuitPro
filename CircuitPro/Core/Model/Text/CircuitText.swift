//
//  CircuitText.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI
import Resolvable

@Resolvable(default: .overridable)
struct CircuitText {
    // MARK: - Content Properties
    
    /// The source that defines the text's string content (e.g., static, dynamic).
    @Identity var contentSource: TextSource
    
    /// A placeholder for the final resolved string.
    @Identity var text: String = ""

    /// Formatting options for dynamically generated text.
    var displayOptions: TextDisplayOptions = .default
    
    // MARK: - Overridable Style & Position Properties
    
    /// The current position, which can be overridden.
    var relativePosition: CGPoint
    
    /// The original position from the definition, used for drawing anchor lines. This is not overridable.
    var anchorPosition: CGPoint
    
    /// The font, stored as a custom Codable `SDFont` struct.
    var font: SDFont = .init(font: .systemFont(ofSize: 12))
    
    /// The color, stored using your `SDColor` struct.
    var color: SDColor = .init(color: .init(nsColor: .black))
    
    /// The text's anchor point.
    var anchor: TextAnchor = .bottomLeading
    
    /// The text alignment, stored as a custom Codable `SDAlignment` enum.
    var alignment: SDAlignment = .center
    
    /// The rotation of the text.
    var cardinalRotation: CardinalRotation = .east
    
    /// The visibility of the text. Can be set to `false` in an override to hide it.
    var isVisible: Bool = true
}
