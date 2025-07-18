import AppKit

struct CursorTool: CanvasTool {

    let id = "cursor"
    let symbolName = CircuitProSymbols.Graphic.cursor
    let label = "Select"

    mutating func handleTap(at location: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        return .noResult // selection logic is handled by CanvasInteractionController
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        // Cursor tool doesn't need a preview — no-op
    }
}
