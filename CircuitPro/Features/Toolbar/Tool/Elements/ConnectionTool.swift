//
//  ConnectionTool.swift
//  CircuitPro
//
//  Updated 02 Jul 2025
//

import SwiftUI
import AppKit

/// Orientation of the last segment: used to flip elbow order in routing strategies.
fileprivate enum RoutingOrientation {
    case horizontal, vertical
}

/// Strategy for computing bend points between two coordinates.
fileprivate protocol RoutingStrategy {
    /// Returns the sequence of intermediate points (excluding the start point) to connect `start` to `end`,
    /// taking into account the previous segment's orientation.
    func route(from start: CGPoint, to end: CGPoint, lastOrientation: RoutingOrientation?) -> [CGPoint]
}

/// Default Manhattan (orthogonal elbow) routing: horizontal vs vertical first.
fileprivate struct ManhattanRoutingStrategy: RoutingStrategy {
    func route(from start: CGPoint, to end: CGPoint, lastOrientation: RoutingOrientation?) -> [CGPoint] {
        // Insert an elbow if both coordinates differ
        if start.x != end.x && start.y != end.y {
            let firstIsVertical = (lastOrientation == .horizontal)
            let elbow = firstIsVertical
                ? CGPoint(x: start.x, y: end.y)
                : CGPoint(x: end.x, y: start.y)
            return [elbow, end]
        }
        // Straight segment
        return [end]
    }
}

struct ConnectionTool: CanvasTool, Equatable, Hashable {

    let id = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Connection"

    // Simple state machine tracker
    private enum Phase: Equatable, Hashable {
        case idle
        case begin(RouteInProgress)
        case running(RouteInProgress)
        case done
        case cancelled
    }

    private var phase: Phase = .idle

    // MARK: - RouteInProgress (The brains of the operation)
    /// A private helper struct that manages the construction of a new Net while the user clicks around the canvas.
    private struct RouteInProgress: Equatable, Hashable {
        var net: Net
        let startNodeID: UUID
        var lastNodeID: UUID
        private(set) var lastOrientation: RoutingOrientation?
        let strategy: RoutingStrategy

        init(startPoint: CGPoint, connectingTo existingElementID: UUID?, strategy: RoutingStrategy) {
            let startNode = Node(id: UUID(), point: startPoint, kind: .endpoint)
            self.net = Net(id: UUID(), nodeByID: [startNode.id: startNode], edges: [])
            self.startNodeID = startNode.id
            self.lastNodeID = startNode.id
            self.strategy = strategy
        }

        // MARK: - Extend Logic (delegates to routing strategy)
        mutating func extend(to point: CGPoint, connectingTo existingNodeID: UUID? = nil) {
            guard let lastNode = net.nodeByID[lastNodeID] else { return }

            // Compute bend points (including final) via strategy
            let bendPoints = strategy.route(from: lastNode.point, to: point, lastOrientation: lastOrientation)

            // Create intermediate bends
            for bend in bendPoints.dropLast() {
                let bendNode = Node(id: UUID(), point: bend, kind: .endpoint)
                net.nodeByID[bendNode.id] = bendNode
                net.edges.append(Edge(id: UUID(), startNodeID: lastNodeID, endNodeID: bendNode.id))
                // Update orientation for this segment
                lastOrientation = (bend.x == lastNode.point.x) ? .vertical : .horizontal
                lastNodeID = bendNode.id
            }

            // Final segment (possibly reusing existing node)
            let finalPoint = bendPoints.last!
            let endID: UUID
            if let existing = existingNodeID {
                endID = existing
            } else {
                let endNode = Node(id: UUID(), point: finalPoint, kind: .endpoint)
                net.nodeByID[endNode.id] = endNode
                endID = endNode.id
            }
            net.edges.append(Edge(id: UUID(), startNodeID: lastNodeID, endNodeID: endID))
            lastOrientation = (finalPoint.x == net.nodeByID[lastNodeID]!.point.x) ? .vertical : .horizontal
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

        // MARK: - Equatable & Hashable (ignoring strategy)
        static func == (lhs: RouteInProgress, rhs: RouteInProgress) -> Bool {
            lhs.net == rhs.net
            && lhs.startNodeID == rhs.startNodeID
            && lhs.lastNodeID == rhs.lastNodeID
            && lhs.lastOrientation == rhs.lastOrientation
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(net)
            hasher.combine(startNodeID)
            hasher.combine(lastNodeID)
            hasher.combine(lastOrientation)
        }
    }

    // MARK: - Tool Actions
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        switch phase {
        case .idle:
            phase = .begin(
                RouteInProgress(
                    startPoint: loc,
                    connectingTo: context.hitSegmentID,
                    strategy: ManhattanRoutingStrategy()
                )
            )
            return nil
        case .begin(var route), .running(var route):
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
                // Only suppress junction dot if splitting at the route's start or end point
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
                targetNodeID = newID
                shouldFinish = true
            }

            // 2. On a double-tap, finish the route.
            if let lastPoint = route.net.nodeByID[lastNodeID]?.point,
               isDoubleTap(from: lastPoint, to: loc) {
                if hitNodeID == lastNodeID {
                    phase = .idle
                    return finishRoute(route)
                }
                route.extend(to: loc, connectingTo: targetNodeID)
                return finishRoute(route)
            }

            route.extend(to: loc, connectingTo: targetNodeID)

            if shouldFinish {
                return finishRoute(route)
            }

            if context.hitSegmentID != nil {
                return finishRoute(route)
            }

            phase = .running(route)
            return nil
        case .done, .cancelled:
            return nil
        }
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        let route: RouteInProgress
        switch phase {
        case .begin(let r), .running(let r):
            route = r
        default:
            return
        }
        guard let lastNode = route.net.nodeByID[route.lastNodeID] else { return }

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
    private mutating func finishRoute(_ finished: RouteInProgress) -> CanvasElement? {
        var route = finished
        guard !route.net.edges.isEmpty else {
            phase = .idle
            return nil
        }

        // 1. Merge colinear segments inside this single route.
        route.net.mergeColinearEdges()

        // 2. Wrap and return.
        let element = ConnectionElement(id: route.net.id, net: route.net)
        phase = .idle
        return .connection(element)
    }

    private mutating func clearState() {
        phase = .idle
    }

    mutating func handleEscape() {
        clearState()
    }

    mutating func handleBackspace() {
        switch phase {
        case .begin(var route), .running(var route):
            route.backtrack()
            if route.net.edges.isEmpty {
                phase = .begin(route)
            } else {
                phase = .running(route)
            }
        default:
            break
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
        return ConnectionElement(id: masterNet.id, net: masterNet)
    }

    // MARK: - Helpers & Conformance
    private func isDoubleTap(from firstPoint: CGPoint, to secondPoint: CGPoint) -> Bool {
        // A simple distance check is sufficient for detecting a double-tap.
        hypot(firstPoint.x - secondPoint.x, firstPoint.y - secondPoint.y) < 5
    }

    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id == rhs.id && lhs.phase == rhs.phase
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(phase)
    }
}
