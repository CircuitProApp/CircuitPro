import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Connection"


    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        print("tapped")
        return nil
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        print("Draw Preview")
    }

    mutating func handleEscape() {  }
    mutating func handleBackspace() {  }

    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
