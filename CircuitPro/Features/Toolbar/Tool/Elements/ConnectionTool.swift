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
    let symbolName = AppIcons.line
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
        private(set) var lastOrientation: Orientation? = nil     // NEW

        init(startPoint: CGPoint, connectingTo existingElementID: UUID?) {
            let startNode = Node(id: UUID(), point: startPoint, kind: .endpoint)
            self.net = Net(id: UUID(), nodeByID: [startNode.id: startNode], edges: [])
            self.lastNodeID = startNode.id
        }

        // MARK: - Extend Logic
        mutating func extend(to point: CGPoint) {
            guard let lastNode = net.nodeByID[lastNodeID] else { return }

            // 1 Decide elbow order (flip default direction when necessary)
            if lastNode.point.x != point.x && lastNode.point.y != point.y {

                let firstIsVertical = (lastOrientation == .horizontal)
                let elbowPoint = firstIsVertical
                    ? CGPoint(x: lastNode.point.x, y: point.y)     // vertical first
                    : CGPoint(x: point.x, y: lastNode.point.y)      // horizontal first

                let elbowNode = Node(id: UUID(), point: elbowPoint, kind: .endpoint)
                net.nodeByID[elbowNode.id] = elbowNode

                let edge1 = Edge(id: UUID(), a: lastNodeID, b: elbowNode.id)
                net.edges.append(edge1)

                lastOrientation = firstIsVertical ? .vertical : .horizontal
                lastNodeID = elbowNode.id
            }

            // 2 Final segment
            let endNode = Node(id: UUID(), point: point, kind: .endpoint)
            net.nodeByID[endNode.id] = endNode

            let edge2 = Edge(id: UUID(), a: lastNodeID, b: endNode.id)
            net.edges.append(edge2)

            lastOrientation = (endNode.point.x == net.nodeByID[lastNodeID]!.point.x)
                ? .vertical : .horizontal
            lastNodeID = endNode.id
        }
    }
    
    // MARK: - Tool Actions
    
    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        // 1. On the first tap, we begin a new route.
        if inProgressRoute == nil {
            inProgressRoute = RouteInProgress(startPoint: loc, connectingTo: context.hitSegmentID)
            return nil
        }

        // 2. On a double-tap, finish the route.
        if let lastPoint = inProgressRoute?.net.nodeByID[inProgressRoute!.lastNodeID]?.point,
           isDoubleTap(from: lastPoint, to: loc) {
            return finishRoute()
        }

        // 3. For subsequent taps, extend the route.
        inProgressRoute?.extend(to: loc)

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
            guard let a = route.net.nodeByID[edge.a],
                  let b = route.net.nodeByID[edge.b] else { continue }
            ctx.move(to: a.point)
            ctx.addLine(to: b.point)
        }
        ctx.strokePath()

        // 2.2 Ghost segment (respect flip rule)
        ctx.setLineDash(phase: 0, lengths: [4])
        let p0 = lastNode.point

        if p0.x != mouse.x && p0.y != mouse.y {
            let firstIsVertical = (route.lastOrientation == .horizontal)
            let elbow = firstIsVertical
                ? CGPoint(x: p0.x, y: mouse.y)
                : CGPoint(x: mouse.x, y: p0.y)

            ctx.move(to: p0)
            ctx.addLine(to: elbow)
            ctx.addLine(to: mouse)
        } else {
            ctx.move(to: p0)
            ctx.addLine(to: mouse)
        }
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // MARK: - Finishing and Merging
    
    /// Finalizes the route, packages it into a ConnectionElement, and clears the tool's state.
    private mutating func finishRoute() -> CanvasElement? {
        guard var route = inProgressRoute, !route.net.edges.isEmpty else {
            clearState()
            return nil
        }
        
        // 1. Merge colinear segments inside this single route.
        route.net.mergeColinearEdges()
        
        // 2. Wrap and return.
        let element = ConnectionElement(id: route.net.id, net: route.net)
        clearState()
        return .connection(element)
    }

    private mutating func clearState() {
        inProgressRoute = nil
    }

    /// This is the new, powerful merging logic. It's called by the canvas controller after a new connection element is created.
    static func merge(_ newElement: ConnectionElement,
                      into elements: inout [CanvasElement]) -> ConnectionElement {

        var master = newElement.net

        for i in (0..<elements.count).reversed() {
            guard case .connection(let otherConn) = elements[i],
                  otherConn.id != newElement.id else { continue }

            var other = otherConn.net

            let joined = Net.findAndMergeIntentionalIntersections(
                            between: &master,
                            and: &other)

            if joined {
                master.nodeByID.merge(other.nodeByID) { cur, _ in cur }
                master.edges.append(contentsOf: other.edges)
                elements.remove(at: i)
            }
        }

        master.mergeColinearEdges()
        return ConnectionElement(id: master.id, net: master)
    }

    // MARK: - Helpers & Conformance
    
    private func isDoubleTap(from a: CGPoint, to b: CGPoint) -> Bool {
        // A simple distance check is sufficient for detecting a double-tap.
        hypot(a.x - b.x, a.y - b.y) < 5
    }

    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id == rhs.id && lhs.inProgressRoute == rhs.inProgressRoute
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(inProgressRoute)
    }
}
