import AppKit

/// The standard selection tool.
///
/// This tool is stateless and primarily serves as a "type" for the canvas to know
/// that it is in selection mode. The actual selection logic is handled by other
/// interactions like `SelectionInteraction`.
final class CursorTool: CanvasTool {

    // MARK: - Overridden Properties

    // We override the base class properties to provide the specific UI for this tool.
    override var symbolName: String { CircuitProSymbols.Graphic.cursor }
    override var label: String { "Select" }
    override var handlesInput: Bool { false }

    // The `id` property is no longer needed; the base class handles identity automatically.

    // MARK: - Overridden Methods

    // The tap behavior is intentionally left blank. The canvas input handler
    // skips tool handling for `CursorTool`, allowing selection/drag interactions
    // to process the event instead.
    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        return .noResult
    }

    // We can provide a custom implementation for `handleEscape`. For the cursor tool,
    // this could mean deselecting all nodes, which is often an expected behavior.
    override func handleEscape() -> Bool {
        // Since this specific tool doesn't manage selection, we don't have direct
        // access to the controller here. The keyboard handling logic in the
        // main controller would be responsible for deselecting nodes when Escape is pressed
        // while the CursorTool is active. Therefore, we can just return false,
        // indicating this tool didn't clear any of its own state.
        return false
    }
}
