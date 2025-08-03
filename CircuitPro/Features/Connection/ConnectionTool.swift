import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id = "connection"
    let symbolName = CircuitProSymbols.Schematic.connectionWire
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
    
    // UPDATED: The method signature now accepts the unified RenderContext.
    mutating func handleTap(at loc: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
         // Access canvas state via the nested renderContext.
         let graph = context.renderContext.schematicGraph
         
         // Access event-specific data directly from the interaction context.
         let clickCount = context.clickCount
         let hitTarget = context.hitTarget

         if clickCount > 1 {
             state = .idle
             return .schematicModified
         }

         switch state {
         case .idle:
             let initialDirection = determineInitialDirection(from: hitTarget)
             state = .drawing(from: hitTarget, at: loc, direction: initialDirection)
             return .noResult

         case .drawing(let startTarget, let startPoint, let direction):
             let endTarget = hitTarget

             if startTarget == nil && endTarget == nil && startPoint == loc { return .noResult }

             let startVertexID = getOrCreateVertex(at: startPoint, from: startTarget, in: graph)
             let endVertexID = getOrCreateVertex(at: loc, from: endTarget, in: graph)

             if startVertexID == endVertexID {
                 state = .idle
                 return .schematicModified
             }
             
             let isStraightLine = (startPoint.x == loc.x || startPoint.y == loc.y)
             let strategy: SchematicGraph.ConnectionStrategy = (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
             graph.connect(from: startVertexID, to: endVertexID, preferring: strategy)

             if endTarget == nil {
                 let newDirection = isStraightLine ? direction.toggled() : direction
                 let newStartTarget = CanvasHitTarget(partID: endVertexID, ownerPath: [], kind: .vertex(type: .corner), position: loc)
                 state = .drawing(from: newStartTarget, at: loc, direction: newDirection)
             } else {
                 state = .idle
             }
         }
         
         return .schematicModified
     }

     // PREVIEW IS CORRECT: Previewing is a rendering concern, so it uses RenderContext.
     mutating func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
         guard case .drawing(_, let startPoint, let direction) = state else { return [] }

         let corner: CGPoint
         switch direction {
         case .horizontal: corner = CGPoint(x: mouse.x, y: startPoint.y)
         case .vertical:   corner = CGPoint(x: startPoint.x, y: mouse.y)
         }
         
         let path = CGMutablePath(); path.move(to: startPoint); path.addLine(to: corner); path.addLine(to: mouse)

         return [DrawingParameters(path: path, lineWidth: 1.5, strokeColor: NSColor.systemBlue.cgColor, lineDashPattern: [4, 2])]
     }

    // MARK: - Tool State Management (Unchanged)
    
    mutating func handleEscape() -> Bool {
        if case .drawing = state {
            state = .idle
            return true
        }
        return false
    }

    mutating func handleReturn() -> CanvasToolResult {
        if case .drawing = state {
            state = .idle
            return .schematicModified
        }
        return .noResult
    }

    mutating func handleBackspace() {
        // This tool's backspace is non-trivial and can be implemented later.
    }
    
    // MARK: - Private Helpers (Unchanged)

    private func getOrCreateVertex(at point: CGPoint, from target: CanvasHitTarget?, in graph: SchematicGraph) -> UUID {
        guard let target = target else {
            return graph.getOrCreateVertex(at: point)
        }

        if case .pin = target.kind, let symbolID = target.ownerPath.last {
            return graph.getOrCreatePinVertex(at: point, symbolID: symbolID, pinID: target.partID)
        }
        
        return graph.getOrCreateVertex(at: point)
    }
    
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        guard let hitTarget = hitTarget, case .edge(let orientation) = hitTarget.kind else {
            return .horizontal
        }

        return orientation == .horizontal ? .vertical : .horizontal
    }
}
