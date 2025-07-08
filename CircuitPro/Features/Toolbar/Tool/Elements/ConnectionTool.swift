//
//  ConnectionTool.swift
//  CircuitPro
//
//  Updated 02 Jul 2025
//

import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Connection"

    // The entire state of the route-in-progress is held here.
    // It's nil when the tool is idle.
    private var inProgressRoute: RouteInProgress?

    // MARK: - RouteInProgress (The brains of the operation)
    /// A private helper struct that manages the construction of a new Net while the user clicks around the canvas.
    private struct RouteInProgress: Equatable, Hashable {

        enum Orientation {
            case horizontal, vertical
        }

        var net: Net
        var lastNodeID: UUID
        private(set) var lastOrientation: Orientation?

        init(startPoint: CGPoint, connectingTo existingElementID: UUID?) {
            let startNode = Node(id: UUID(), point: startPoint, kind: .endpoint)
            self.net = Net(id: UUID(), nodeByID: [startNode.id: startNode], edges: [])
            self.lastNodeID = startNode.id
        }

        // MARK: - Extend Logic
        mutating func extend(to point: CGPoint, connectingTo existingNodeID: UUID? = nil) {
            guard let lastNode = net.nodeByID[lastNodeID] else { return }

            // 1 Decide elbow order (flip default direction when necessary)
            if lastNode.point.x != point.x && lastNode.point.y != point.y {

                let firstIsVertical = (lastOrientation == .horizontal)
                let elbowPoint = firstIsVertical
                    ? CGPoint(x: lastNode.point.x, y: point.y)     // vertical first
                    : CGPoint(x: point.x, y: lastNode.point.y)      // horizontal first

                let elbowNode = Node(id: UUID(), point: elbowPoint, kind: .endpoint)
                net.nodeByID[elbowNode.id] = elbowNode

                let edge1 = Edge(id: UUID(), startNodeID: lastNodeID, endNodeID: elbowNode.id)
                net.edges.append(edge1)

                lastOrientation = firstIsVertical ? .vertical : .horizontal
                lastNodeID = elbowNode.id
            }

            // 2 Final segment
            let endID: UUID
            if let existingID = existingNodeID {
                endID = existingID
            } else {
                let endNode = Node(id: UUID(), point: point, kind: .endpoint)
                net.nodeByID[endNode.id] = endNode
                endID = endNode.id
            }

            let edge2 = Edge(id: UUID(), startNodeID: lastNodeID, endNodeID: endID)
            net.edges.append(edge2)

            let endPoint = net.nodeByID[endID]!.point
            lastOrientation = (endPoint.x == net.nodeByID[lastNodeID]!.point.x)
                ? .vertical : .horizontal
            lastNodeID = endID
        }

        mutating func backtrack() {
            guard let lastEdge = net.edges.popLast() else {
                return
            }

            if net.edges.allSatisfy({ $0.startNodeID != lastEdge.endNodeID && $0.endNodeID != lastEdge.endNodeID }) {
                net.nodeByID.removeValue(forKey: lastEdge.endNodeID)
            }

            lastNodeID = lastEdge.startNodeID

            if let prevEdge = net.edges.last,
               let start = net.nodeByID[prevEdge.startNodeID],
               let end = net.nodeByID[prevEdge.endNodeID] {
                lastOrientation = (start.point.x == end.point.x) ? .vertical : .horizontal
            } else {
                lastOrientation = nil
            }
        }
    }

    // MARK: - Tool Actions
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        // 1. On the first tap, we begin a new route.
        if inProgressRoute == nil {
            inProgressRoute = RouteInProgress(startPoint: loc, connectingTo: context.hitSegmentID)
            return nil
        }

        var targetNodeID: UUID? = nil
        var shouldFinish = false

        let lastNodeID = inProgressRoute!.lastNodeID
        let hitNodeID = inProgressRoute?.net.nodeID(at: loc)

        if let nodeID = hitNodeID, nodeID != lastNodeID {
            if var node = inProgressRoute?.net.nodeByID[nodeID] {
                node.kind = .junction
                inProgressRoute?.net.nodeByID[nodeID] = node
            }
            targetNodeID = nodeID
            shouldFinish = true
        } else if hitNodeID == nil,
                  let edgeID = inProgressRoute?.net.edgeID(containing: loc),
                  let newID = inProgressRoute?.net.splitEdge(withID: edgeID, at: loc) {
            targetNodeID = newID
            shouldFinish = true
        }

        // 2. On a double-tap, finish the route.
        if let lastPoint = inProgressRoute?.net.nodeByID[lastNodeID]?.point,
           isDoubleTap(from: lastPoint, to: loc) {
            if hitNodeID == lastNodeID {
                return finishRoute()
            }
            inProgressRoute?.extend(to: loc, connectingTo: targetNodeID)
            return finishRoute()
        }

        inProgressRoute?.extend(to: loc, connectingTo: targetNodeID)

        if shouldFinish {
            return finishRoute()
        }

        // 4. If this tap landed on another wire, finish the route automatically.
        if context.hitSegmentID != nil {
            return finishRoute()
        }

        return nil
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let route = inProgressRoute,
              let lastNode = route.net.nodeByID[route.lastNodeID] else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)

        // 2.1 Already-fixed segments
        for edge in route.net.edges {
            guard let nodeA = route.net.nodeByID[edge.startNodeID],
                  let nodeB = route.net.nodeByID[edge.endNodeID] else { continue }
            ctx.move(to: nodeA.point)
            ctx.addLine(to: nodeB.point)
        }
        ctx.strokePath()

        // 2.2 Ghost segment (respect flip rule)
        ctx.setLineDash(phase: 0, lengths: [4])
        let startPoint = lastNode.point

        if startPoint.x != mouse.x && startPoint.y != mouse.y {
            let firstSegmentIsVertical = (route.lastOrientation == .horizontal)
            let elbowPoint = firstSegmentIsVertical
                ? CGPoint(x: startPoint.x, y: mouse.y)
                : CGPoint(x: mouse.x, y: startPoint.y)

            ctx.move(to: startPoint)
            ctx.addLine(to: elbowPoint)
            ctx.addLine(to: mouse)
        } else {
            ctx.move(to: startPoint)
            ctx.addLine(to: mouse)
        }

        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Finalizes the route, packages it into a ConnectionElement, and clears the tool's state.
    private mutating func finishRoute() -> CanvasElement? {
        guard var route = inProgressRoute, !route.net.edges.isEmpty else {
            clearState()
            return nil
        }

        // 1. Merge colinear segments inside this single route.
        route.net.mergeColinearEdges()
        route.net.downgradeRedundantJunctions()

        // 2. Wrap and return.
        let element = ConnectionElement(id: route.net.id, net: route.net)
        clearState()
        return .connection(element)
    }

    private mutating func clearState() {
        inProgressRoute = nil
    }

    mutating func handleEscape() {
        clearState()
    }

    mutating func handleBackspace() {
        guard var route = inProgressRoute else { return }
        route.backtrack()
        if route.net.edges.isEmpty {
            inProgressRoute = nil
        } else {
            inProgressRoute = route
        }
    }

    static func merge(
        _ newElement: ConnectionElement,
        into elements: inout [CanvasElement]
    ) -> ConnectionElement {

        var masterNet = newElement.net

        for index in (0..<elements.count).reversed() {
            guard case .connection(let existingConnection) = elements[index],
                  existingConnection.id != newElement.id else { continue }

            var existingNet = existingConnection.net

            let wasMerged = Net.findAndMergeIntentionalIntersections(
                between: &masterNet,
                and: &existingNet
            )

            if wasMerged {
                masterNet.nodeByID.merge(existingNet.nodeByID) { currentNode, _ in currentNode }
                masterNet.edges.append(contentsOf: existingNet.edges)
                elements.remove(at: index)
            }
        }

        masterNet.mergeColinearEdges()
        masterNet.downgradeRedundantJunctions()
        return ConnectionElement(id: masterNet.id, net: masterNet)
    }

    // MARK: - Helpers & Conformance
    private func isDoubleTap(from firstPoint: CGPoint, to secondPoint: CGPoint) -> Bool {
        // A simple distance check is sufficient for detecting a double-tap.
        hypot(firstPoint.x - secondPoint.x, firstPoint.y - secondPoint.y) < 5
    }

    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id == rhs.id && lhs.inProgressRoute == rhs.inProgressRoute
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(inProgressRoute)
    }
}
