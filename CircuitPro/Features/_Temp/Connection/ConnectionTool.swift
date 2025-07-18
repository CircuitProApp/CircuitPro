import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
    let label = "Connection"

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        // The hit target where the connection started, and the starting point.
        case drawing(from: CanvasHitTarget?, at: CGPoint)
    }

    private var state: State = .idle

    // MARK: – CanvasTool Conformance
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasToolResult {
        guard let graph = context.schematicGraph else {
            assertionFailure("ConnectionTool requires a schematic graph in the context.")
            return .noResult
        }

        // On a double-click, finalize the current drawing operation.
        if context.clickCount > 1 {
            state = .idle
            return .schematicModified
        }

        switch state {
        case .idle:
            // Start a new drawing from the current hit target and location.
            state = .drawing(from: context.hitTarget, at: loc)
            // We return noResult because the graph hasn't been modified yet.
            return .noResult

        case .drawing(let startTarget, let startPoint):
            let endTarget = context.hitTarget

            // If the user clicks the same spot they started from, and it's not on a specific target,
            // it's likely an accidental click. We do nothing and wait for the next valid point.
            if startTarget == nil && endTarget == nil && startPoint == loc {
                return .noResult
            }
            
            let startVertexID = getOrCreateVertex(for: startTarget, at: startPoint, in: graph)
            let endVertexID = getOrCreateVertex(for: endTarget, at: loc, in: graph)
            
            // Do not create a connection if the start and end points are the same vertex.
            if startVertexID == endVertexID {
                state = .idle
                return .schematicModified
            }
            
            // Connect the two vertices.
            graph.connect(from: startVertexID, to: endVertexID)
            
            // If the connection ended on a specific target (not empty space),
            // finalize the drawing operation. Otherwise, continue from the new point.
            if endTarget == nil {
                // Continue drawing. The new start target is the vertex we just created.
                let newStartTarget = CanvasHitTarget.connection(
                    part: .vertex(id: endVertexID, position: loc, type: .corner) // Using .corner as a placeholder
                )
                state = .drawing(from: newStartTarget, at: loc)
            } else {
                state = .idle
            }
        }
        
        return .schematicModified
    }

    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard case .drawing(_, let startPoint) = state else { return }

        // Draw an orthogonal preview line from the last point to the mouse.
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
        if case .drawing = state {
            state = .idle
        }
    }

    mutating func handleReturn() -> CanvasToolResult {
        if case .drawing = state {
            state = .idle
            return .schematicModified
        }
        return .noResult
    }

    mutating func handleBackspace() {
        // TODO: Implement backspace to remove the last segment.
    }
    
    // MARK: - Private Helpers
    
    /// Resolves a hit target and a location into a vertex ID.
    /// This is the authoritative method for determining which vertex a click corresponds to.
    /// It will create a new vertex if the click is on an edge, a pin, or in empty space.
    private func getOrCreateVertex(for hitTarget: CanvasHitTarget?, at point: CGPoint, in graph: SchematicGraph) -> ConnectionVertex.ID {
        switch hitTarget {
        case .connection(.vertex(let id, _, _)):
            // The click was directly on an existing vertex. Use it.
            return id
            
        case .connection(.edge(let id, _, _)):
            // The click was on an edge. Split the edge and return the new vertex.
            return graph.splitEdgeAndInsertVertex(edgeID: id, at: point)!
            
        case .canvasElement(.pin(_, _, let pinPosition)):
            // The click was on a component pin. Create a new vertex at the pin's exact location.
            // Note: This correctly uses the pin's position, not the raw click location.
            // Future improvement: Check if a vertex already exists at this position.
            return graph.addVertex(at: pinPosition).id
            
        case .canvasElement, .none:
            // The click was in empty space or on another part of a canvas element.
            // Create a new vertex at the click location.
            // Future improvement: Check if a vertex already exists at this position.
            return graph.addVertex(at: point).id
        }
    }
}