//
//  ResolvedText.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/2/25.
//

import SwiftUI

/// A unified view model representing a text element for display on the canvas.
/// It has been "resolved" from a definition or an instance.
struct ResolvedText: Identifiable {
    var id: UUID {
        // The stable ID is derived from its source.
        switch origin {
        case .definition(let definitionID):
            return definitionID
        case .instance(let instanceID):
            return instanceID
        }
    }
    
    // --- Data provenance ---
    let origin: TextOrigin
    
    // --- Content and styling ---
    var text: String
    var font: NSFont
    var color: CGColor
    var alignment: NSTextAlignment
    
    // --- Positional data ---
    var relativePosition: CGPoint // The final position relative to the parent symbol.
    var anchorRelativePosition: CGPoint // The original anchor relative position.
    var cardinalRotation: CardinalRotation
}
