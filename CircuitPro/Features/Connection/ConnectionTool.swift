import SwiftUI
import AppKit

/// A stateful tool for drawing orthogonal connections. This tool is fully generic and
/// emits its results as `ConnectionRequestNode` instances via the CanvasToolResult.
final class ConnectionTool: CanvasTool {

    // MARK: - UI Representation
    override var symbolName: String { "waveform.path" }
    override var label: String { "Connection" }

    // MARK: - Internal State
    private enum DrawingDirection {
        case horizontal
        case vertical
        func toggled() -> DrawingDirection { self == .horizontal ? .vertical : .horizontal }
    }

    private enum State {
        case idle
        case drawing(startPoint: CGPoint, direction: DrawingDirection)
    }

    private var state: State = .idle

    // MARK: - Primary Actions
    override func handleTap(at location: CGPoint, context: ToolInteractionContext) -> CanvasToolResult {
        switch self.state {
        case .idle:
            // First click: Start drawing.
            let initialDirection = determineInitialDirection(from: context.hitTarget)
            self.state = .drawing(startPoint: location, direction: initialDirection)
            return .noResult // No model change yet.

        case .drawing(let startPoint, let direction):
            // Second click: A segment is complete.
            
            // Ignore clicks at the exact same location.
            if startPoint == location { return .noResult }

            // Create the request node. This is a lightweight message, not a real visual node.
            let strategy: SchematicGraph.ConnectionStrategy = (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
            let requestNode = ConnectionRequestNode(from: startPoint, to: location, strategy: strategy)
            
            // If the user clicked on an existing pin or wire, the tool's job is done.
            if context.hitTarget != nil {
                self.state = .idle
            } else {
                // Otherwise, continue drawing from the new point.
                let isStraightLine = (startPoint.x == location.x || startPoint.y == location.y)
                let newDirection = isStraightLine ? direction.toggled() : direction
                self.state = .drawing(startPoint: location, direction: newDirection)
            }
            
            // Return the request to be handled by the interaction layer.
            return .newNode(requestNode)
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingParameters] {
        guard case .drawing(let startPoint, let direction) = state else { return [] }
        let corner = (direction == .horizontal) ? CGPoint(x: mouse.x, y: startPoint.y) : CGPoint(x: startPoint.x, y: mouse.y)
        let path = CGMutablePath(); path.move(to: startPoint); path.addLine(to: corner); path.addLine(to: mouse)
        return [DrawingParameters(path: path, lineWidth: 1.5, strokeColor: NSColor.systemBlue.cgColor, lineDashPattern: [4, 2])]
    }
    
    // MARK: - Keyboard Actions
    override func handleEscape() -> Bool {
        if case .drawing = self.state {
            self.state = .idle
            return true
        }
        return false
    }

    override func handleReturn() -> CanvasToolResult {
//        let wasDrawing = (self.state != .idle)
        self.state = .idle
        // We don't return a result here, as finishing doesn't create a new connection.
        // Returning a repaint request might be useful if the state change requires it.
        return  .noResult
    }
    
    // MARK: - Private Helpers
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        // This helper no longer has access to the graph, so it can't check wire orientation.
        // A more advanced version could inspect node *tags* or properties if you add them,
        // but for now, defaulting is the simplest decoupled approach.
        return .horizontal
    }
}
