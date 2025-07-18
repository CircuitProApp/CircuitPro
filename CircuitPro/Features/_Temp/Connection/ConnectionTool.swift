import SwiftUI
import AppKit

// In your CanvasToolContext definition:
// var schematicGraph: SchematicGraph

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // The tool's state is now extremely simple: just the ID of the last vertex we added.
    private var lastVertexID: UUID?
    private var isDrawing: Bool { lastVertexID != nil }
    var isIdle: Bool { !isDrawing }

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        
        return .noResult
    }
    
    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {

    }


    // MARK: - Tool State Management
    mutating func handleEscape() {
 
    }
    
    mutating func handleReturn() -> CanvasToolResult {


        return .noResult
    }
    
    mutating func handleBackspace() {

    }
}
