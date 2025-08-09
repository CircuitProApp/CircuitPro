import SwiftUI
import AppKit

/// A stateful tool for drawing orthogonal connections. This tool is fully generic and
/// emits its results as `ConnectionRequestNode` instances via the CanvasToolResult.
final class ConnectionTool: CanvasTool {

    // MARK: - UI Representation
    override var symbolName: String { CircuitProSymbols.Schematic.connectionWire }
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
            let initialDirection = determineInitialDirection(from: context.hitTarget)
            self.state = .drawing(startPoint: location, direction: initialDirection)
            return .noResult

        case .drawing(let startPoint, let direction):
            // Same-point click
            if startPoint == location {
                // Double-click at the same location stops the tool
                if context.clickCount >= 2 {
                    self.state = .idle
                }
                // Either way, no new segment from a zero-length click
                return .noResult
            }

            // Create the request node
            let strategy: SchematicGraph.ConnectionStrategy =
                (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
            let requestNode = ConnectionRequestNode(from: startPoint, to: location, strategy: strategy)

            // Finish only when hitting a pin or anything in the schematic graph subtree
            if shouldFinish(on: context.hitTarget) {
                self.state = .idle
            } else {
                // Continue drawing from the new point, toggling direction only for straight lines
                let isStraightLine = (startPoint.x == location.x || startPoint.y == location.y)
                let newDirection = isStraightLine ? direction.toggled() : direction
                self.state = .drawing(startPoint: location, direction: newDirection)
            }

            return .newNode(requestNode)
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard case .drawing(let startPoint, let direction) = state else { return [] }
        
        // Calculate the corner point for the two-segment orthogonal line.
        let corner = (direction == .horizontal) ? CGPoint(x: mouse.x, y: startPoint.y) : CGPoint(x: startPoint.x, y: mouse.y)
        
        // Create the path for the preview.
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: corner)
        path.addLine(to: mouse)
        
        // Return a single stroke primitive with the specified styling.
        return [.stroke(
            path: path,
            color: NSColor.systemBlue.cgColor,
            lineWidth: 1.0, // Default line width
            lineDash: [4, 4]
        )]
    }
    
    private func shouldFinish(on hit: CanvasHitTarget?) -> Bool {
        guard let node = hit?.node else { return false }
        if node is PinNode { return true }
        return belongsToSchematicGraph(node)
    }
    
    // MARK: - Keyboard Actions
    override func handleEscape() -> Bool {
        if case .drawing = self.state {
            self.state = .idle
            return true
        }
        return false
    }
    
    private func belongsToSchematicGraph(_ node: BaseNode) -> Bool {
        var current: BaseNode? = node
        while let c = current {
            if c is SchematicGraphNode { return true }
            current = c.parent
        }
        return false
    }
    
    // MARK: - Private Helpers
    private func determineInitialDirection(from hitTarget: CanvasHitTarget?) -> DrawingDirection {
        guard let hitTarget = hitTarget else {
            // Clicked in empty space, default to horizontal.
            return .horizontal
        }

        // Check if the partIdentifier contains a LineOrientation.
        if let orientation = hitTarget.partIdentifier as? LineOrientation {
            // We hit a wire! Start drawing perpendicular to it.
            return orientation == .horizontal ? .vertical : .horizontal
        }
        
        // We hit something else (a vertex, a pin, etc.). Default to horizontal.
        return .horizontal
    }
}
