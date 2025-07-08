import CoreGraphics
import AppKit

extension ConnectionController {
    enum Event {
        case tap(CGPoint, CanvasToolContext)
        case doubleTap(CGPoint, CanvasToolContext)
        case move(CGPoint)
        case backspace
        case escape
    }

    enum State {
        case idle
        case startingRoute
        case extendingRoute
        case cancelling
    }
}

final class ConnectionController {
    private let repository: NetRepository
    private let builder = RouteBuilder()
    private(set) var state: State = .idle

    init(repository: NetRepository) {
        self.repository = repository
    }


    func handle(event: Event) -> CanvasElement? {
        switch (state, event) {
        case (.idle, .tap(let loc, let context)):
            builder.start(at: loc, connectingTo: context.hitSegmentID)
            state = .startingRoute
            return nil

        case (.startingRoute, .tap(let loc, let context)),
             (.extendingRoute, .tap(let loc, let context)):
            let result = processTap(at: loc, context: context, finalize: false)
            state = builder.snapshot == nil ? .idle : .extendingRoute
            return result

        case (.startingRoute, .doubleTap(let loc, let context)),
             (.extendingRoute, .doubleTap(let loc, let context)):
            let result = processTap(at: loc, context: context, finalize: true)
            state = .idle
            return result

        case (_, .backspace):
            builder.backtrack()
            state = builder.snapshot == nil ? .idle : .extendingRoute
            return nil

        case (_, .escape):
            builder.cancel()
            state = .idle
            return nil

        case (_, .move):
            return nil
        }
    }

    func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard state != .idle,
              let route = builder.snapshot,
              let lastNode = route.net.nodeByID[route.lastNodeID] else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)

        for edge in route.net.edges {
            guard let nodeA = route.net.nodeByID[edge.startNodeID],
                  let nodeB = route.net.nodeByID[edge.endNodeID] else { continue }
            ctx.move(to: nodeA.point)
            ctx.addLine(to: nodeB.point)
        }
        ctx.strokePath()

        ctx.setLineDash(phase: 0, lengths: [4])
        let startPoint = lastNode.point
        if startPoint.x != mouse.x && startPoint.y != mouse.y {
            let firstVertical = (route.lastOrientation == .horizontal)
            let elbow = firstVertical ? CGPoint(x: startPoint.x, y: mouse.y) : CGPoint(x: mouse.x, y: startPoint.y)
            ctx.move(to: startPoint)
            ctx.addLine(to: elbow)
            ctx.addLine(to: mouse)
        } else {
            ctx.move(to: startPoint)
            ctx.addLine(to: mouse)
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    func handleEscape() { _ = handle(event: .escape) }
    func handleBackspace() { _ = handle(event: .backspace) }

    private func processTap(at loc: CGPoint, context: CanvasToolContext, finalize: Bool) -> CanvasElement? {
        guard var route = builder.snapshot else { return nil }
        var targetNodeID: UUID? = nil
        var shouldFinish = false

        let lastNodeID = route.lastNodeID
        let hitNodeID = route.net.nodeID(at: loc)

        if let nodeID = hitNodeID, nodeID != lastNodeID {
            if var node = route.net.nodeByID[nodeID] {
                node.kind = .junction
                route.net.nodeByID[nodeID] = node
            }
            targetNodeID = nodeID
            shouldFinish = true
        } else if hitNodeID == nil,
                  let edgeID = route.net.edgeID(containing: loc),
                  let newID = route.net.splitEdge(withID: edgeID, at: loc) {
            if let splitNode = route.net.nodeByID[newID] {
                let tol: CGFloat = 0.5
                let startPt = route.net.nodeByID[route.startNodeID]?.point
                let endPt = route.net.nodeByID[route.lastNodeID]?.point
                if (startPt != nil && abs(splitNode.point.x - startPt!.x) < tol && abs(splitNode.point.y - startPt!.y) < tol)
                    || (endPt != nil && abs(splitNode.point.x - endPt!.x) < tol && abs(splitNode.point.y - endPt!.y) < tol) {
                    var node = splitNode
                    node.kind = .endpoint
                    route.net.nodeByID[newID] = node
                }
            }
            targetNodeID = newID
            shouldFinish = true
        }

        if finalize {
            if hitNodeID == lastNodeID {
                return self.finalize()
            }
            builder.extend(to: loc, connectingTo: targetNodeID)
            return self.finalize()
        }

        builder.extend(to: loc, connectingTo: targetNodeID)

        if shouldFinish { return finalize() }
        if context.hitSegmentID != nil { return finalize() }
        return nil
    }

    private func finalize() -> CanvasElement? {
        guard let net = builder.finishRoute() else { return nil }
        repository.add(net)
        let element = ConnectionElement(id: net.id, net: net)
        return .connection(element)
    }

}
