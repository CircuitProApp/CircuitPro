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
//    private let wireEngine: WireEngine
//
//    init(wireEngine: WireEngine) {
//        self.wireEngine = wireEngine
//        super.init()
//    }

    // MARK: - Primary Actions
    override func handleTap(at location: CGPoint, context: ToolInteractionContext)
        -> CanvasToolResult
    {
        switch self.state {
        case .idle:
            let initialDirection = determineInitialDirection(
                graphHit: nil, context: context.renderContext)
            self.state = .drawing(startPoint: location, direction: initialDirection)
            return .noResult

        case .drawing(let startPoint, let direction):
//            // Same-point click
//            if startPoint == location {
//                // Double-click at the same location stops the tool
//                if context.clickCount >= 2 {
//                    self.state = .idle
//                }
//                // Either way, no new segment from a zero-length click
//                return .noResult
//            }
//
//            // Create the request node
//            let strategy: WireEngine.WireConnectionStrategy =
//                (direction == .horizontal) ? .horizontalThenVertical : .verticalThenHorizontal
//            let fromPoint = startPoint
//            let toPoint = location
//
//            // Finish only when hitting a pin or anything in the schematic graph subtree
//            if shouldFinish(at: location, context: context.renderContext) {
//                self.state = .idle
//            } else {
//                // Continue drawing from the new point, toggling direction only for straight lines
//                let isStraightLine = (startPoint.x == location.x || startPoint.y == location.y)
//                let newDirection = isStraightLine ? direction.toggled() : direction
//                self.state = .drawing(startPoint: location, direction: newDirection)
//            }
//            Task { @MainActor in
//                wireEngine.connect(from: fromPoint, to: toPoint, preferring: strategy)
//            }
            return .noResult
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
        guard let itemHit = CanvasHitTester().hitTest(point: location, context: context) else {
            return false
        }

        if let item = context.items.first(where: { $0.id == itemHit }),
            item is Pin
        {
            return true
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
    private func determineInitialDirection(graphHit: UUID?, context: RenderContext)
        -> DrawingDirection
    {
        return .horizontal
    }

}
