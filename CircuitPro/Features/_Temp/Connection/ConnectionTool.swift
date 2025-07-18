import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        case drawing(from: CanvasHitTarget?, at: CGPoint)
    }

    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }

        if context.clickCount > 1 {
            state = .idle
            return .schematicModified
        }

        switch state {
        case .idle:
            state = .drawing(from: context.hitTarget, at: loc)
            return .noResult

        case .drawing(let startTarget, let startPoint):
            let endTarget = context.hitTarget

            if startTarget == nil && endTarget == nil && startPoint == loc { return .noResult }
            
            // The tool's responsibility is now simple: get the start and end vertex IDs
            // using the model's authoritative function.
            let startVertexID = graph.getOrCreateVertex(at: startPoint)
            let endVertexID = graph.getOrCreateVertex(at: loc)
            
            if startVertexID == endVertexID {
                state = .idle
                return .schematicModified
            }
            
            // Then tell the model to connect them. The model handles all complex merge logic.
            graph.connect(from: startVertexID, to: endVertexID)
            
            if endTarget == nil {
                let newStartTarget = CanvasHitTarget.connection(part: .vertex(id: endVertexID, position: loc, type: .corner))
                state = .drawing(from: newStartTarget, at: loc)
            } else {
                state = .idle
            }
        }
        
        return .schematicModified
    }

    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard case .drawing(_, let startPoint) = state else { return }

        ctx.setStrokeColor(NSColor.systemGreen.cgColor)
        ctx.setLineWidth(1.0 / context.magnification)
        ctx.setLineDash(phase: 0, lengths: [4 / context.magnification, 2 / context.magnification])
        let corner = CGPoint(x: mouse.x, y: startPoint.y)
        ctx.move(to: startPoint)
        ctx.addLine(to: corner)
        ctx.addLine(to: mouse)
        ctx.strokePath()
    }

    // MARK: - Tool State Management
    mutating func handleEscape() {
        if case .drawing = state { state = .idle }
    }

    mutating func handleReturn() -> CanvasToolResult {
        if case .drawing = state {
            state = .idle
            return .schematicModified
        }
        return .noResult
    }

    mutating func handleBackspace() {
        // TODO: Implement backspace
    }
}
