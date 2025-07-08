import CoreGraphics
import Foundation

enum RoutingOrientation {
    case horizontal, vertical
}

protocol RoutingStrategy {
    func route(from start: CGPoint, to end: CGPoint, lastOrientation: RoutingOrientation?) -> [CGPoint]
}

struct ManhattanRoutingStrategy: RoutingStrategy {
    func route(from start: CGPoint, to end: CGPoint, lastOrientation: RoutingOrientation?) -> [CGPoint] {
        if start.x != end.x && start.y != end.y {
            let firstIsVertical = (lastOrientation == .horizontal)
            let elbow = firstIsVertical
                ? CGPoint(x: start.x, y: end.y)
                : CGPoint(x: end.x, y: start.y)
            return [elbow, end]
        }
        return [end]
    }
}

final class RouteBuilder {
    private struct RouteInProgress: Equatable, Hashable {
        var net: Net
        let startNodeID: UUID
        var lastNodeID: UUID
        var lastOrientation: RoutingOrientation?
        let strategy: RoutingStrategy

        init(startPoint: CGPoint, connectingTo existingElementID: UUID?, strategy: RoutingStrategy) {
            let startNode = Node(id: UUID(), point: startPoint, kind: .endpoint)
            self.net = Net(id: UUID(), nodeByID: [startNode.id: startNode], edges: [])
            self.startNodeID = startNode.id
            self.lastNodeID = startNode.id
            self.strategy = strategy
        }

        mutating func extend(to point: CGPoint, connectingTo existingNodeID: UUID? = nil) {
            guard let lastNode = net.nodeByID[lastNodeID] else { return }
            let bendPoints = strategy.route(from: lastNode.point, to: point, lastOrientation: lastOrientation)
            for bend in bendPoints.dropLast() {
                let bendNode = Node(id: UUID(), point: bend, kind: .endpoint)
                net.nodeByID[bendNode.id] = bendNode
                net.edges.append(Edge(id: UUID(), startNodeID: lastNodeID, endNodeID: bendNode.id))
                lastOrientation = (bend.x == lastNode.point.x) ? .vertical : .horizontal
                lastNodeID = bendNode.id
            }
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
            guard let lastEdge = net.edges.popLast() else { return }
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

    private var route: RouteInProgress?

    var snapshot: RouteInProgress? { route }

    func start(at point: CGPoint, connectingTo existingID: UUID?) {
        route = RouteInProgress(startPoint: point, connectingTo: existingID, strategy: ManhattanRoutingStrategy())
    }

    func extend(to point: CGPoint, connectingTo existingNodeID: UUID? = nil) {
        route?.extend(to: point, connectingTo: existingNodeID)
    }

    func backtrack() {
        route?.backtrack()
        if route?.net.edges.isEmpty == true { route = nil }
    }

    func finishRoute() -> Net? {
        guard var current = route, !current.net.edges.isEmpty else {
            route = nil
            return nil
        }
        current.net.mergeColinearEdges()
        route = nil
        return current.net
    }

    func cancel() { route = nil }
}
