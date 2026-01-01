import AppKit
import SwiftUI

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
    private let wireEngine: WireEngine

    init(wireEngine: WireEngine) {
        self.wireEngine = wireEngine
        super.init()
    }

    // MARK: - Primary Actions
    override func handleTap(at location: CGPoint, context: ToolInteractionContext)
        -> CanvasToolResult
    {
        switch self.state {
        case .idle:
            let graphHit = GraphHitTester().hitTest(point: location, context: context.renderContext)
            let initialDirection = determineInitialDirection(
                graphHit: graphHit, context: context.renderContext)
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

            return .command(
                CanvasToolCommand { [wireEngine] _, _ in
                    wireEngine.connect(from: fromPoint, to: toPoint, preferring: strategy)
                })
        }
    }

    override func preview(mouse: CGPoint, context: RenderContext) -> [DrawingPrimitive] {
        guard case .drawing(let startPoint, let direction) = state else { return [] }

        // Calculate the corner point for the two-segment orthogonal line.
        let corner =
            (direction == .horizontal)
            ? CGPoint(x: mouse.x, y: startPoint.y) : CGPoint(x: startPoint.x, y: mouse.y)

        // Create the path for the preview.
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: corner)
        path.addLine(to: mouse)

        // Return a single stroke primitive with the specified styling.
        return [
            .stroke(
                path: path,
                color: NSColor.systemBlue.cgColor,
                lineWidth: 1.0,  // Default line width
                lineDash: [4, 4]
            )
        ]
    }

    private func shouldFinish(at location: CGPoint, context: RenderContext) -> Bool {
        let graph = context.graph
        guard let graphHit = GraphHitTester().hitTest(point: location, context: context) else {
            return false
        }

        switch graphHit {
        case .node(let nodeID):
            if graph.component(CanvasPin.self, for: nodeID) != nil {
                return true
            }
        case .edge(let edgeID):
            return graph.component(WireEdgeComponent.self, for: edgeID) != nil
        }
        return false
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
    private func determineInitialDirection(graphHit: GraphElementID?, context: RenderContext)
        -> DrawingDirection
    {
        if let graphHit, let orientation = wireOrientation(for: graphHit, in: context) {
            return orientation == .horizontal ? .vertical : .horizontal
        }

        return .horizontal
    }

    private func wireOrientation(for id: GraphElementID, in context: RenderContext) -> EdgeOrientation? {
        let graph = context.graph
        guard case .edge(let edgeID) = id,
            let edge = graph.component(WireEdgeComponent.self, for: edgeID)
        else { return nil }
        let dx = abs(edge.startPoint.x - edge.endPoint.x)
        let dy = abs(edge.startPoint.y - edge.endPoint.y)
        return dx < 1e-6 ? .vertical : .horizontal
    }

}
