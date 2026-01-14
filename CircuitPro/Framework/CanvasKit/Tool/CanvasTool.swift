//
//  CanvasTool.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

/// An abstract base class for all canvas tools.
///
/// Using a class hierarchy allows for type-safe checking (e.g., `if tool is CursorTool`)
/// and provides a natural way for stateful tools (like a multi-point line tool) to manage
/// their own state without needing `mutating` methods.
class CanvasTool: Hashable {

    // MARK: - Identity and Conformance

    /// The tool's identity, derived from its specific type. This ensures that
    /// all instances of `CursorTool` are equal, but different from `LineTool`.
    public var id: ObjectIdentifier {
        return ObjectIdentifier(type(of: self))
    }

    public static func == (lhs: CanvasTool, rhs: CanvasTool) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - UI Representation (for Toolbars)

    /// The SF Symbol name to represent this tool in the UI. Subclasses should override this.
    var symbolName: String { "questionmark.circle" }

    /// The user-facing name for this tool. Subclasses should override this.
    var label: String { "Unnamed Tool" }

    /// Whether the tool should handle direct pointer input.
    /// Selection tools should return false to let hit targets handle events.
    var handlesInput: Bool { true }


    // MARK: - Primary Actions (Override in Subclasses)

    /// Called when the user taps on the canvas. Subclasses override this to provide their main behavior.
    /// This method is NOT `mutating` because classes are reference types.
    func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        return .noResult
    }

    /// Provides a temporary preview view (e.g., rubber-banding a line).
    func preview(
        mouse: CGPoint,
        context: RenderContext,
        environment: CanvasEnvironmentValues
    ) -> CKGroup {
        return CKGroup()
    }

    // MARK: - Keyboard Actions (Override in Subclasses)

    /// Called when the Escape key is pressed. Resets the tool's internal state.
    /// - Returns: `true` if the tool had in-progress state that was cleared.
    func handleEscape() -> Bool {
        return false
    }

    /// Called when the Backspace key is pressed. Undoes the most recent step.
    func handleBackspace() {
        // Default implementation does nothing.
    }

    /// Called when the 'R' key is pressed, typically for rotation.
    func handleRotate() {
        // Default implementation does nothing.
    }

    /// Called when the Return key is pressed. Commits the current operation.
    func handleReturn() -> CanvasToolResult {
        return .noResult
    }
}
