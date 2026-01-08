import CoreGraphics
import Foundation

struct ManhattanRoute: ConnectionRoute {
    let points: [CGPoint]
}

struct ManhattanWireEngine: ConnectionEngine {
    var preferHorizontalFirst: Bool = true

    func routes(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionRoutingContext
    ) -> [UUID: any ConnectionRoute] {
        let pointsByID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.position) })
        var output: [UUID: any ConnectionRoute] = [:]
        output.reserveCapacity(links.count)

        for link in links {
            guard let a = pointsByID[link.startID],
                  let b = pointsByID[link.endID]
            else { continue }

            let start = context.snapPoint(a)
            let end = context.snapPoint(b)
            output[link.id] = ManhattanRoute(points: [start, end])
        }

        return output
    }

    func normalize(
        points: [any ConnectionPoint],
        links: [any ConnectionLink],
        context: ConnectionNormalizationContext
    ) -> ConnectionDelta {
        var pointsByID = Dictionary(
            uniqueKeysWithValues: points.map { ($0.id, context.snapPoint($0.position)) }
        )
        let linksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        let originalIDs = Set(linksByID.keys)
        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)

        var anchorIndex: [PositionKey: UUID] = [:]
        anchorIndex.reserveCapacity(points.count)
        for (id, position) in pointsByID {
            anchorIndex[PositionKey(position: position, epsilon: epsilon)] = id
        }

        var addedPoints: [any CanvasItem & ConnectionPoint] = []
        var splitLinks: [WireSegment] = []
        splitLinks.reserveCapacity(links.count * 2)

        for link in links {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else {
                splitLinks.append(WireSegment(id: link.id, startID: link.startID, endID: link.endID))
                continue
            }

            let dx = end.x - start.x
            let dy = end.y - start.y

            if abs(dx) <= epsilon || abs(dy) <= epsilon {
                splitLinks.append(WireSegment(id: link.id, startID: link.startID, endID: link.endID))
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
                pointsByID[cornerID] = corner
                addedPoints.append(vertex)
            }

            splitLinks.append(WireSegment(id: link.id, startID: link.startID, endID: cornerID))
            splitLinks.append(WireSegment(startID: cornerID, endID: link.endID))
        }

        if splitLinks.isEmpty {
            return ConnectionDelta()
        }

        var segments: [EdgeSegment] = []
        segments.reserveCapacity(splitLinks.count)
        var passthroughLinks: [WireSegment] = []

        for link in splitLinks {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else {
                passthroughLinks.append(link)
                continue
            }

            let dx = end.x - start.x
            let dy = end.y - start.y

            if abs(dx) <= epsilon {
                let minY = min(start.y, end.y)
                let maxY = max(start.y, end.y)
                let minID = start.y <= end.y ? link.startID : link.endID
                let maxID = start.y <= end.y ? link.endID : link.startID
                segments.append(
                    EdgeSegment(
                        id: link.id,
                        orientation: .vertical,
                        fixed: start.x,
                        min: minY,
                        max: maxY,
                        minPointID: minID,
                        maxPointID: maxID
                    )
                )
            } else if abs(dy) <= epsilon {
                let minX = min(start.x, end.x)
                let maxX = max(start.x, end.x)
                let minID = start.x <= end.x ? link.startID : link.endID
                let maxID = start.x <= end.x ? link.endID : link.startID
                segments.append(
                    EdgeSegment(
                        id: link.id,
                        orientation: .horizontal,
                        fixed: start.y,
                        min: minX,
                        max: maxX,
                        minPointID: minID,
                        maxPointID: maxID
                    )
                )
            } else {
                passthroughLinks.append(link)
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
        var mergedLinks: [WireSegment] = []

        for group in grouped.values {
            let sorted = group.sorted { $0.min < $1.min }
            guard var current = sorted.first else { continue }
            var sourceIDs = [current.id]

            for segment in sorted.dropFirst() {
                if segment.min <= current.max + epsilon {
                    if segment.min < current.min {
                        current.min = segment.min
                        current.minPointID = segment.minPointID
                    }
                    if segment.max > current.max {
                        current.max = segment.max
                        current.maxPointID = segment.maxPointID
                    }
                    current.max = max(current.max, segment.max)
                    sourceIDs.append(segment.id)
                } else {
                    let keepID = selectKeepID(from: sourceIDs, preferred: originalIDs)
                    let normalized = WireSegment(
                        id: keepID,
                        startID: current.minPointID,
                        endID: current.maxPointID
                    )
                    mergedLinks.append(normalized)
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
                startID: current.minPointID,
                endID: current.maxPointID
            )
            mergedLinks.append(normalized)
            for id in sourceIDs where id != keepID {
                removedIDs.insert(id)
            }
        }

        let mergedIDs = Set(mergedLinks.map { $0.id })
        for link in passthroughLinks where !mergedIDs.contains(link.id) {
            mergedLinks.append(link)
        }

        var removedOriginalIDs = Set<UUID>()
        for id in removedIDs where originalIDs.contains(id) {
            removedOriginalIDs.insert(id)
        }

        var updatedLinks: [any CanvasItem & ConnectionLink] = []
        var addedLinks: [any CanvasItem & ConnectionLink] = []

        for link in mergedLinks {
            if let original = linksByID[link.id] {
                if original.startID == link.startID && original.endID == link.endID {
                    continue
                }
                updatedLinks.append(link)
            } else {
                addedLinks.append(link)
            }
        }

        if addedPoints.isEmpty && removedOriginalIDs.isEmpty && updatedLinks.isEmpty && addedLinks.isEmpty {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedPointIDs: [],
            updatedPoints: [],
            addedPoints: addedPoints,
            removedLinkIDs: removedOriginalIDs,
            updatedLinks: updatedLinks,
            addedLinks: addedLinks
        )
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
        var minPointID: UUID
        var maxPointID: UUID
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
