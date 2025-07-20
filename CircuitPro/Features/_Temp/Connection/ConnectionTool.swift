import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire // Assuming this exists
    let label = "Connection"

    // MARK: - Types
    private enum DrawingDirection: Equatable, Hashable {
        case horizontal
        case vertical

        func toggled() -> DrawingDirection {
            self == .horizontal ? .vertical : .horizontal
        }
    }

    // MARK: - State
    private enum State: Equatable, Hashable {
        case idle
        case drawing(from: CanvasHitTarget?, at: CGPoint, direction: DrawingDirection)
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
            // 1. Determine initial drawing direction from the hit target
            let initialDirection = determineInitialDirection(from: context.hitTarget)
            state = .drawing(from: context.hitTarget, at: loc, direction: initialDirection)
            return .noResult

        case .drawing(let startTarget, let startPoint, let direction):
            let endTarget = context.hitTarget

            if startTarget == nil && endTarget == nil && startPoint == loc { return .noResult }

            let startVertexID = getOrCreateVertex(at: startPoint, from: startTarget, in: graph)
            let endVertexID = getOrCreateVertex(at: loc, from: endTarget, in: graph)

            if startVertexID == endVertexID {
                state = .idle
                return .schematicModified
            }

            // 2. Determine if the requested connection is a straight line
            let isStraightLine = (startPoint.x == loc.x || startPoint.y == loc.y)

            // 3. Connect vertices using the current direction strategy
            let strategy: SchematicGraph.ConnectionStrategy = (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
            graph.connect(from: startVertexID, to: endVertexID, preferring: strategy)

            // 4. Update state for the next segment
            if endTarget == nil {
                // 4.1. Only toggle the direction if a straight line was just drawn
                let newDirection = isStraightLine ? direction.toggled() : direction
                
                // FIXME: The VertexType here is a guess. We don't have enough info.
                let newStartTarget = CanvasHitTarget.connection(part: .vertex(id: endVertexID, position: loc, type: .corner))
                state = .drawing(from: newStartTarget, at: loc, direction: newDirection)
            } else {
                state = .idle
            }
        }
        
        return .schematicModified
    }

    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        // 1. Get drawing state, including the direction
        guard case .drawing(_, let startPoint, let direction) = state else { return }

        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setLineWidth(1.0 / context.magnification)
        ctx.setLineDash(phase: 0, lengths: [4 / context.magnification, 2 / context.magnification])

        // 2. Determine corner based on current drawing direction
        let corner: CGPoint
        switch direction {
        case .horizontal:
            corner = CGPoint(x: mouse.x, y: startPoint.y)
        case .vertical:
            corner = CGPoint(x: startPoint.x, y: mouse.y)
        }
        
        // 3. Draw the preview lines
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
    
    // MARK: - Private Helpers
    
    /// Gets or creates a vertex in the graph, using pin information if available.
    private func getOrCreateVertex(at point: CGPoint, from target: CanvasHitTarget?, in graph: SchematicGraph) -> UUID {
        if let target = target, case .canvasElement(let part) = target, case .pin(let pinID, let symbolID, _) = part {
            // This is a pin, so create a special vertex for it.
            return graph.getOrCreatePinVertex(at: point, symbolID: symbolID!, pinID: pinID)
        } else {
            // This is a free point or a junction on an existing wire.
            return graph.getOrCreateVertex(at: point)
        }
    }
    
    /// Determines the initial drawing direction based on the object under the cursor.
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        guard let hitTarget = hitTarget else {
            // Default to horizontal when starting in an empty space.
            return .horizontal
        }

        // 1. Check if the hit target is a connection, specifically an edge.
        guard case .connection(let part) = hitTarget,
              case .edge(_, _, let orientation) = part else {
            // Default to horizontal for vertices, canvas elements, etc.
            return .horizontal
        }

        // 2. Use the edge's orientation to set the next drawing direction.
        switch orientation {
        case .horizontal:
            // Start drawing vertically from a horizontal edge.
            return .vertical
        case .vertical:
            // Start drawing horizontally from a vertical edge.
            return .horizontal
        }
    }
}
