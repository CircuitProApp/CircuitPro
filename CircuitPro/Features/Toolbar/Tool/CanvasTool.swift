//
//  CanvasTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

protocol CanvasTool: Hashable {
    var id: String { get }
    var symbolName: String { get }
    var label: String { get }

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasElement?

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext)

    // NEW: keyboard actions -------------------------------------------------
    /// Called when the user presses the Escape key while this tool is active.
    /// Tools can reset any in-progress state here.
    mutating func handleEscape()

    /// Called when the Backspace key is pressed. Tools should undo the most
    /// recent step of the operation if possible.
    mutating func handleBackspace()
}

extension CanvasTool {
    mutating func handleTap(at location: CGPoint) -> CanvasElement? {
        handleTap(at: location, context: CanvasToolContext())
    }

    mutating func handleEscape() {}

    mutating func handleBackspace() {}
}
