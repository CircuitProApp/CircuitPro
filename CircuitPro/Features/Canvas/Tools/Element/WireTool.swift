import SwiftUI
import AppKit

/// A stateful tool for drawing orthogonal wires.
final class WireTool: CanvasTool {

    // MARK: - UI Representation
    override var symbolName: String { CircuitProSymbols.Schematic.wire }
    override var label: String { "Wire" }

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
            let graphHit = GraphHitTester().hitTest(point: location, context: context.renderContext, scope: .graphOnly)
            let initialDirection = determineInitialDirection(graphHit: graphHit, context: context.renderContext)
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
            let strategy: WireEngine.WireConnectionStrategy =
                (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
            let fromPoint = startPoint
            let toPoint = location

            // Finish only when hitting a pin or anything in the schematic graph subtree
            if shouldFinish(at: location, context: context.renderContext) {
                self.state = .idle
            } else {
                // Continue drawing from the new point, toggling direction only for straight lines
                let isStraightLine = (startPoint.x == location.x || startPoint.y == location.y)
                let newDirection = isStraightLine ? direction.toggled() : direction
                self.state = .drawing(startPoint: location, direction: newDirection)
            }

            return .command(CanvasToolCommand { interactionContext, _ in
                guard let wireEngine = interactionContext.renderContext.environment.wireEngine else {
                    return
                }
                wireEngine.connect(from: fromPoint, to: toPoint, preferring: strategy)
            })
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

    private func shouldFinish(at location: CGPoint, context: RenderContext) -> Bool {
        guard let graph = context.graph,
              let graphHit = GraphHitTester().hitTest(point: location, context: context, scope: .graphOnly) else {
            return false
        }

        if graph.component(GraphPinComponent.self, for: graphHit) != nil {
            return true
        }

        return graph.component(WireEdgeComponent.self, for: graphHit) != nil
    }

    // MARK: - Keyboard Actions
    override func handleEscape() -> Bool {
        if case .drawing = self.state {
            self.state = .idle
            return true
        }
        return false
    }

    // MARK: - Private Helpers
    private func determineInitialDirection(graphHit: NodeID?, context: RenderContext) -> DrawingDirection {
        if let graphHit, let orientation = wireOrientation(for: graphHit, in: context) {
            return orientation == .horizontal ? .vertical : .horizontal
        }

        return .horizontal
    }

    private func wireOrientation(for id: NodeID, in context: RenderContext) -> EdgeOrientation? {
        guard let graph = context.graph,
              let edge = graph.component(WireEdgeComponent.self, for: id),
              let start = graph.component(WireVertexComponent.self, for: edge.start),
              let end = graph.component(WireVertexComponent.self, for: edge.end) else {
            return nil
        }
        let dx = abs(start.point.x - end.point.x)
        let dy = abs(start.point.y - end.point.y)
        return dx < 1e-6 ? .vertical : .horizontal
    }
}
