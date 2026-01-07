import CoreGraphics
import Foundation

struct ManhattanRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct ManhattanWireEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    func routes(
        from input: ConnectionInput,
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        let (anchorsByID, relations) = resolve(input: input)

        var output: [UUID: any ConnectionRoute] = [:]
        output.reserveCapacity(relations.count)

        for rel in relations {
            guard let a = anchorsByID[rel.a],
                  let b = anchorsByID[rel.b]
            else { continue }

            let start = context.snapPoint(a)
            let end = context.snapPoint(b)
            output[rel.id] = ManhattanRoute(points: [start, end])
        }

        return output
    }

    func normalize(
        _ input: ConnectionInput,
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        guard case .edges(let anchors, let edges) = input else {
            return ConnectionDelta()
        }

        var anchorsByID = Dictionary(
            uniqueKeysWithValues: anchors.map { ($0.id, context.snapPoint($0.position)) }
        )
        let edgesByID = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        let originalIDs = Set(edgesByID.keys)
        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)

        var anchorIndex: [PositionKey: UUID] = [:]
        anchorIndex.reserveCapacity(anchors.count)
        for (id, position) in anchorsByID {
            anchorIndex[PositionKey(position: position, epsilon: epsilon)] = id
        }

        var addedAnchors: [any CanvasItem & ConnectionAnchor] = []
        var splitEdges: [WireSegment] = []
        splitEdges.reserveCapacity(edges.count * 2)

        for edge in edges {
            guard let start = anchorsByID[edge.startID],
                  let end = anchorsByID[edge.endID]
            else {
                splitEdges.append(WireSegment(id: edge.id, startID: edge.startID, endID: edge.endID))
                continue
            }

            let dx = end.x - start.x
            let dy = end.y - start.y

            if abs(dx) <= epsilon || abs(dy) <= epsilon {
                splitEdges.append(WireSegment(id: edge.id, startID: edge.startID, endID: edge.endID))
                continue
            }

            let corner = preferHorizontalFirst
                ? CGPoint(x: end.x, y: start.y)
                : CGPoint(x: start.x, y: end.y)

            let cornerKey = PositionKey(position: corner, epsilon: epsilon)
            let cornerID: UUID
            if let existing = anchorIndex[cornerKey] {
                cornerID = existing
            } else {
                let vertex = WireVertex(position: corner)
                cornerID = vertex.id
                anchorIndex[cornerKey] = cornerID
                anchorsByID[cornerID] = corner
                addedAnchors.append(vertex)
            }

            splitEdges.append(WireSegment(id: edge.id, startID: edge.startID, endID: cornerID))
            splitEdges.append(WireSegment(startID: cornerID, endID: edge.endID))
        }

        if splitEdges.isEmpty {
            return ConnectionDelta()
        }

        var segments: [EdgeSegment] = []
        segments.reserveCapacity(splitEdges.count)
        var passthroughEdges: [WireSegment] = []

        for edge in splitEdges {
            guard let start = anchorsByID[edge.startID],
                  let end = anchorsByID[edge.endID]
            else {
                passthroughEdges.append(edge)
                continue
            }

            let dx = end.x - start.x
            let dy = end.y - start.y

            if abs(dx) <= epsilon {
                let minY = min(start.y, end.y)
                let maxY = max(start.y, end.y)
                let minID = start.y <= end.y ? edge.startID : edge.endID
                let maxID = start.y <= end.y ? edge.endID : edge.startID
                segments.append(
                    EdgeSegment(
                        id: edge.id,
                        orientation: .vertical,
                        fixed: start.x,
                        min: minY,
                        max: maxY,
                        minAnchorID: minID,
                        maxAnchorID: maxID
                    )
                )
            } else if abs(dy) <= epsilon {
                let minX = min(start.x, end.x)
                let maxX = max(start.x, end.x)
                let minID = start.x <= end.x ? edge.startID : edge.endID
                let maxID = start.x <= end.x ? edge.endID : edge.startID
                segments.append(
                    EdgeSegment(
                        id: edge.id,
                        orientation: .horizontal,
                        fixed: start.y,
                        min: minX,
                        max: maxX,
                        minAnchorID: minID,
                        maxAnchorID: maxID
                    )
                )
            } else {
                passthroughEdges.append(edge)
            }
        }

        struct SegmentKey: Hashable {
            let orientation: Orientation
            let bucket: Int
        }

        func bucket(for value: CGFloat) -> Int {
            Int((value / epsilon).rounded())
        }

        var grouped: [SegmentKey: [EdgeSegment]] = [:]
        for segment in segments {
            let key = SegmentKey(
                orientation: segment.orientation,
                bucket: bucket(for: segment.fixed)
            )
            grouped[key, default: []].append(segment)
        }

        var removedIDs = Set<UUID>()
        var mergedEdges: [WireSegment] = []

        for group in grouped.values {
            let sorted = group.sorted { $0.min < $1.min }
            guard var current = sorted.first else { continue }
            var sourceIDs = [current.id]

            for segment in sorted.dropFirst() {
                if segment.min <= current.max + epsilon {
                    if segment.min < current.min {
                        current.min = segment.min
                        current.minAnchorID = segment.minAnchorID
                    }
                    if segment.max > current.max {
                        current.max = segment.max
                        current.maxAnchorID = segment.maxAnchorID
                    }
                    current.max = max(current.max, segment.max)
                    sourceIDs.append(segment.id)
                } else {
                    let keepID = selectKeepID(from: sourceIDs, preferred: originalIDs)
                    let normalized = WireSegment(
                        id: keepID,
                        startID: current.minAnchorID,
                        endID: current.maxAnchorID
                    )
                    mergedEdges.append(normalized)
                    for id in sourceIDs where id != keepID {
                        removedIDs.insert(id)
                    }

                    current = segment
                    sourceIDs = [segment.id]
                }
            }

            let keepID = selectKeepID(from: sourceIDs, preferred: originalIDs)
            let normalized = WireSegment(
                id: keepID,
                startID: current.minAnchorID,
                endID: current.maxAnchorID
            )
            mergedEdges.append(normalized)
            for id in sourceIDs where id != keepID {
                removedIDs.insert(id)
            }
        }

        let mergedIDs = Set(mergedEdges.map { $0.id })
        for edge in passthroughEdges where !mergedIDs.contains(edge.id) {
            mergedEdges.append(edge)
        }

        var removedOriginalIDs = Set<UUID>()
        for id in removedIDs where originalIDs.contains(id) {
            removedOriginalIDs.insert(id)
        }

        var updatedEdges: [any CanvasItem & ConnectionEdge] = []
        var addedEdges: [any CanvasItem & ConnectionEdge] = []

        for edge in mergedEdges {
            if let original = edgesByID[edge.id] {
                if original.startID == edge.startID && original.endID == edge.endID {
                    continue
                }
                updatedEdges.append(edge)
            } else {
                addedEdges.append(edge)
            }
        }

        if addedAnchors.isEmpty && removedOriginalIDs.isEmpty && updatedEdges.isEmpty && addedEdges.isEmpty {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedAnchorIDs: [],
            updatedAnchors: [],
            addedAnchors: addedAnchors,
            removedEdgeIDs: removedOriginalIDs,
            updatedEdges: updatedEdges,
            addedEdges: addedEdges
        )
    }

    private struct Relation {
        let id: UUID
        let a: UUID
        let b: UUID
    }

    private func resolve(
        input: ConnectionInput
    ) -> ([UUID: CGPoint], [Relation]) {
        switch input {
        case .edges(let anchors, let edges):
            let anchorsByID = Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0.position) })
            let relations = edges.map { Relation(id: $0.id, a: $0.startID, b: $0.endID) }
            return (anchorsByID, relations)

        case .adjacency(let anchors, let points):
            let anchorsByID = Dictionary(uniqueKeysWithValues: anchors.map { ($0.id, $0.position) })
            var relations: [Relation] = []
            var seen = Set<String>()

            for point in points {
                for otherID in point.connectedIDs {
                    let key = point.id.uuidString < otherID.uuidString
                        ? "\(point.id.uuidString)|\(otherID.uuidString)"
                        : "\(otherID.uuidString)|\(point.id.uuidString)"
                    if seen.contains(key) { continue }
                    seen.insert(key)
                    relations.append(Relation(id: UUID(), a: point.id, b: otherID))
                }
            }
            return (anchorsByID, relations)
        }
    }

    private enum Orientation: Hashable {
        case horizontal
        case vertical
    }

    private struct EdgeSegment {
        let id: UUID
        let orientation: Orientation
        let fixed: CGFloat
        var min: CGFloat
        var max: CGFloat
        var minAnchorID: UUID
        var maxAnchorID: UUID
    }

    private struct PositionKey: Hashable {
        let x: Int
        let y: Int

        init(position: CGPoint, epsilon: CGFloat) {
            x = Int((position.x / epsilon).rounded())
            y = Int((position.y / epsilon).rounded())
        }
    }

    private func selectKeepID(from ids: [UUID], preferred: Set<UUID>) -> UUID {
        for id in ids where preferred.contains(id) {
            return id
        }
        return ids.first ?? UUID()
    }
}
