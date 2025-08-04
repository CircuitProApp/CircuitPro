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

    // MARK: - Connection Tool Properties

    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters]

    // NEW: keyboard actions -------------------------------------------------
    /// Called when the user presses the Escape key while this tool is active.
    /// Tools can reset any in-progress state here.
    /// Returns bool if any progress was cleared.
    mutating func handleEscape() -> Bool

    /// Called when the Backspace key is pressed. Tools should undo the most
    /// recent step of the operation if possible.
    mutating func handleBackspace()

    /// Called when the R key is pressed. Tools can use this to cycle through
    /// discrete rotation states or otherwise adjust orientation.
    mutating func handleRotate()

    /// Called when the Return key is pressed. Tools should commit the
    /// existing steps if possible.
    mutating func handleReturn() -> CanvasToolResult
}

extension CanvasTool {
    mutating func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        // Default implementation that returns .noResult.
        return .noResult
    }

    mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] { [] }

    mutating func handleEscape() {}

    mutating func handleBackspace() {}

    mutating func handleRotate() {}

    mutating func handleReturn() -> CanvasToolResult { .noResult }
}
