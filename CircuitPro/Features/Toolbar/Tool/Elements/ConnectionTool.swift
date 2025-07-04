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
        var net: Net
        var lastNodeID: UUID // The ID of the node at the end of the current route.
        
        init(startPoint: CGPoint, connectingTo existingElementID: UUID?) {
            let startNode = Node(id: UUID(), point: startPoint, kind: .endpoint)
            self.net = Net(id: UUID(), nodeByID: [startNode.id: startNode], edges: [])
            self.lastNodeID = startNode.id

            // If we started on an existing wire, we might need to handle splitting/joining later.
            // For now, this is a placeholder for that future logic.
        }

        /// Adds a point to the route, extending from the last point with orthogonal segments.
        mutating func extend(to point: CGPoint) {
            guard let lastNode = net.nodeByID[lastNodeID] else { return }

            // Create the intermediate elbow node if needed for an L-shaped segment.
            if lastNode.point.x != point.x && lastNode.point.y != point.y {
                let elbowPoint = CGPoint(x: point.x, y: lastNode.point.y)
                let elbowNode = Node(id: UUID(), point: elbowPoint, kind: .endpoint)
                net.nodeByID[elbowNode.id] = elbowNode
                
                let edge1 = Edge(id: UUID(), a: lastNodeID, b: elbowNode.id)
                net.edges.append(edge1)
                
                // The new "last node" is the elbow.
                lastNodeID = elbowNode.id
            }

            // Create the final node at the target point.
            let endNode = Node(id: UUID(), point: point, kind: .endpoint)
            net.nodeByID[endNode.id] = endNode

            let edge2 = Edge(id: UUID(), a: lastNodeID, b: endNode.id)
            net.edges.append(edge2)
            
            // The new "last node" is now the end point.
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

    mutating func handleKeyDown(_ event: NSEvent, context: CanvasToolContext) -> CanvasElement? {
        // Finish the route if the user presses Return (key code 36).
        if event.keyCode == 36 {
            return finishRoute()
        }
        return nil
    }
    
    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        guard let route = inProgressRoute, let lastNode = route.net.nodeByID[route.lastNodeID] else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1)
        
        // Draw the segments already committed to the in-progress net.
        for edge in route.net.edges {
            guard let nodeA = route.net.nodeByID[edge.a], let nodeB = route.net.nodeByID[edge.b] else { continue }
            ctx.move(to: nodeA.point)
            ctx.addLine(to: nodeB.point)
        }
        ctx.strokePath()

        // Draw the dashed "ghost" line from the last point to the current mouse cursor.
        ctx.setLineDash(phase: 0, lengths: [4])
        let startPoint = lastNode.point
        if startPoint.x != mouse.x && startPoint.y != mouse.y {
             let elbowPoint = CGPoint(x: mouse.x, y: startPoint.y)
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
    static func merge(_ newElement: ConnectionElement, into elements: inout [CanvasElement]) -> ConnectionElement {
        
        // 1. Start with the net from the newly created element. This will be our "master" net.
        var masterNet = newElement.net
        
        // 2. We must iterate backwards to safely remove elements as we merge them.
        for i in (0..<elements.count).reversed() {
            
            // 3. Get the other element, making sure it's a connection we can merge with.
            guard case .connection(let otherConn) = elements[i],
                  otherConn.id != newElement.id else {
                continue
            }
            
            // 4. Create a mutable copy of the other net to work with.
            var otherNet = otherConn.net
            
            // 5. This is the magic. We check for intersections. If found, this function
            // modifies both masterNet and otherNet, splitting edges and creating shared junctions.
            let didIntersect = Net.findAndMergeIntersections(between: &masterNet, and: &otherNet)
            
            // 6. If they were connected, we merge the graphs.
            if didIntersect {
                // Absorb the nodes and edges from the other net into our master net.
                masterNet.nodeByID.merge(otherNet.nodeByID) { (current, _) in current }
                masterNet.edges.append(contentsOf: otherNet.edges)
                
                // Since the other connection has been absorbed, remove it from the canvas.
                elements.remove(at: i)
            }
        }
        
        // 7. Return a new ConnectionElement containing the final, fully merged net.
        masterNet.mergeColinearEdges()
        return ConnectionElement(id: masterNet.id, net: masterNet)
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

// Net+Graph.swift

import Foundation
import CoreGraphics

// A temporary, private struct used only for geometry calculations.
fileprivate struct LineSegment {
    var start: CGPoint
    var end: CGPoint
    var isHorizontal: Bool { start.y == end.y }
    var isVertical:   Bool { start.x == end.x }

    // Finds the intersection point between two orthogonal line segments.
    func intersectionPoint(with other: LineSegment) -> CGPoint? {
        if self.isHorizontal && other.isVertical {
            if self.start.y.isBetween(other.start.y, other.end.y) &&
               other.start.x.isBetween(self.start.x, self.end.x) {
                return CGPoint(x: other.start.x, y: self.start.y)
            }
        } else if self.isVertical && other.isHorizontal {
            if self.start.x.isBetween(other.start.x, other.end.x) &&
               other.start.y.isBetween(self.start.y, self.end.y) {
                return CGPoint(x: self.start.x, y: other.start.y)
            }
        }
        return nil
    }
}

extension Net {
    
    /// Splits an existing edge at a specific point, creating a new junction node and two new edges.
    /// - Returns: The ID of the new junction node created at the split point.
    @discardableResult
    mutating func splitEdge(withID edgeID: UUID, at point: CGPoint) -> UUID? {
        // 1. Find the original edge and its start/end nodes.
        guard let originalEdgeIndex = self.edges.firstIndex(where: { $0.id == edgeID }),
              let nodeA = self.nodeByID[self.edges[originalEdgeIndex].a],
              let nodeB = self.nodeByID[self.edges[originalEdgeIndex].b] else {
            return nil
        }

        // 2. Create the new node that will form the junction.
        let junctionNode = Node(id: UUID(), point: point, kind: .junction)
        self.nodeByID[junctionNode.id] = junctionNode
        
        // 3. Create two new edges to replace the original one.
        let newEdge1 = Edge(id: UUID(), a: nodeA.id, b: junctionNode.id)
        let newEdge2 = Edge(id: UUID(), a: junctionNode.id, b: nodeB.id)

        // 4. Remove the original edge and add the two new ones.
        self.edges.remove(at: originalEdgeIndex)
        self.edges.append(contentsOf: [newEdge1, newEdge2])
        
        return junctionNode.id
    }
    
    /// Finds all intersections between two nets, splits the affected edges in both,
    /// and establishes shared junction nodes to link them topologically.
    /// - Returns: `true` if any intersections were found and merged.
    static func findAndMergeIntersections(between netA: inout Net, and netB: inout Net) -> Bool {
        var intersectionsFound = false
        var intersectionPoints: [(edgeA_ID: UUID, edgeB_ID: UUID, point: CGPoint)] = []

        // 1. First, find all geometric intersection points without changing anything.
        // This prevents mutation-during-iteration problems.
        for edgeA in netA.edges {
            guard let nodeA_start = netA.nodeByID[edgeA.a], let nodeA_end = netA.nodeByID[edgeA.b] else { continue }
            let segA = LineSegment(start: nodeA_start.point, end: nodeA_end.point)
            
            for edgeB in netB.edges {
                guard let nodeB_start = netB.nodeByID[edgeB.a], let nodeB_end = netB.nodeByID[edgeB.b] else { continue }
                let segB = LineSegment(start: nodeB_start.point, end: nodeB_end.point)
                
                if let point = segA.intersectionPoint(with: segB) {
                    intersectionsFound = true
                    intersectionPoints.append((edgeA.id, edgeB.id, point))
                }
            }
        }
        
        // 2. Now, process the intersections.
        guard intersectionsFound else { return false }
        
        for intersection in intersectionPoints {
            // Split the edge in Net A, creating a new junction node.
            let junctionNodeID = netA.splitEdge(withID: intersection.edgeA_ID, at: intersection.point)
            
            // Split the edge in Net B, but instead of creating a new node,
            // we will link it to the junction node created in Net A.
            if let junctionNodeID = junctionNodeID,
               let edgeB_Index = netB.edges.firstIndex(where: { $0.id == intersection.edgeB_ID }),
               let nodeB_A = netB.nodeByID[netB.edges[edgeB_Index].a],
               let nodeB_B = netB.nodeByID[netB.edges[edgeB_Index].b] {

                let newEdge1 = Edge(id: UUID(), a: nodeB_A.id, b: junctionNodeID)
                let newEdge2 = Edge(id: UUID(), a: junctionNodeID, b: nodeB_B.id)
                
                netB.edges.remove(at: edgeB_Index)
                netB.edges.append(contentsOf: [newEdge1, newEdge2])
            }
        }
        
        return true
    }
}
