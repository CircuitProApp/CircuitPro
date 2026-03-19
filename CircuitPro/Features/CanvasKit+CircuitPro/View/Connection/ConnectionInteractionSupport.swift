import AppKit
import SwiftUI

enum ConnectionInteractionMode {
    case orthogonal
    case octilinear
}

enum ConnectionSegmentOrientation {
    case horizontal
    case vertical
    case diagonalAscending
    case diagonalDescending
    case arbitrary

    var direction: CGVector? {
        switch self {
        case .horizontal:
            return CGVector(dx: 1, dy: 0)
        case .vertical:
            return CGVector(dx: 0, dy: 1)
        case .diagonalAscending:
            let v = 1 / sqrt(2.0)
            return CGVector(dx: v, dy: v)
        case .diagonalDescending:
            let v = 1 / sqrt(2.0)
            return CGVector(dx: v, dy: -v)
        case .arbitrary:
            return nil
        }
    }
}

enum ConnectionInteractionSupport {
    static func applyNormalization(
        to items: inout [any CanvasItem],
        engine: any ConnectionEngine,
        context: RenderContext,
        environment: CanvasEnvironmentValues,
        points: [any ConnectionPoint],
        links: [any ConnectionLink]
    ) {
        guard !points.isEmpty, !links.isEmpty else { return }

        let normalizationContext = ConnectionNormalizationContext(
            magnification: context.magnification,
            snapPoint: { point in
                context.snapProvider.snap(point: point, context: context, environment: environment)
            }
        )
        let delta = engine.normalize(points: points, links: links, context: normalizationContext)
        apply(delta: delta, to: &items)
    }

    static func apply(delta: ConnectionDelta, to items: inout [any CanvasItem]) {
        guard !delta.isEmpty else { return }

        if !delta.removedLinkIDs.isEmpty || !delta.removedPointIDs.isEmpty {
            items.removeAll { item in
                delta.removedLinkIDs.contains(item.id)
                    || delta.removedPointIDs.contains(item.id)
            }
        }

        if !delta.updatedPoints.isEmpty
            || !delta.addedPoints.isEmpty
            || !delta.updatedLinks.isEmpty
            || !delta.addedLinks.isEmpty
        {
            var indexByID: [UUID: Int] = [:]
            indexByID.reserveCapacity(items.count)
            for (index, item) in items.enumerated() {
                indexByID[item.id] = index
            }

            func upsert(_ item: any CanvasItem) {
                if let index = indexByID[item.id] {
                    items[index] = item
                } else {
                    items.append(item)
                    indexByID[item.id] = items.count - 1
                }
            }

            for point in delta.updatedPoints {
                upsert(point)
            }
            for point in delta.addedPoints {
                upsert(point)
            }
            for link in delta.updatedLinks {
                upsert(link)
            }
            for link in delta.addedLinks {
                upsert(link)
            }
        }
    }

    static func hasLink(
        between a: UUID,
        and b: UUID,
        links: [any ConnectionLink]
    ) -> Bool {
        for link in links {
            if (link.startID == a && link.endID == b)
                || (link.startID == b && link.endID == a)
            {
                return true
            }
        }
        return false
    }

    static func buildOrientationMap(
        for links: [any ConnectionLink],
        positions: [UUID: CGPoint],
        tolerance: CGFloat,
        mode: ConnectionInteractionMode,
        cache: inout [UUID: ConnectionSegmentOrientation]
    ) -> [UUID: ConnectionSegmentOrientation] {
        var map: [UUID: ConnectionSegmentOrientation] = [:]
        map.reserveCapacity(links.count)
        var currentIDs = Set<UUID>()
        currentIDs.reserveCapacity(links.count)

        for link in links {
            currentIDs.insert(link.id)
            guard let start = positions[link.startID],
                let end = positions[link.endID]
            else { continue }

            let orientation = classify(
                start: start,
                end: end,
                tolerance: tolerance,
                mode: mode
            )

            // Geometry can legitimately flip during a drag sequence or after
            // normalization, so the cached orientation has to track the latest
            // endpoint positions instead of being treated as immutable.
            cache[link.id] = orientation
            map[link.id] = orientation
        }

        cache = cache.filter { currentIDs.contains($0.key) }
        return map
    }

    static func classify(
        start: CGPoint,
        end: CGPoint,
        tolerance: CGFloat,
        mode: ConnectionInteractionMode
    ) -> ConnectionSegmentOrientation {
        let dx = end.x - start.x
        let dy = end.y - start.y

        if abs(dx) <= tolerance {
            return .vertical
        }
        if abs(dy) <= tolerance {
            return .horizontal
        }
        if mode == .octilinear, abs(abs(dx) - abs(dy)) <= tolerance {
            let sameSign = (dx >= 0 && dy >= 0) || (dx <= 0 && dy <= 0)
            return sameSign ? .diagonalAscending : .diagonalDescending
        }
        return .arbitrary
    }

    static func linkAdjacency(for links: [any ConnectionLink]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in links {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    static func linkEndpointMap(for links: [any ConnectionLink]) -> [UUID: (UUID, UUID)] {
        var map: [UUID: (UUID, UUID)] = [:]
        map.reserveCapacity(links.count)
        for link in links {
            map[link.id] = (link.startID, link.endID)
        }
        return map
    }

    static func fixedPointIDs(
        in points: [any ConnectionPoint],
        movablePoint: any ConnectionPoint.Type
    ) -> Set<UUID> {
        var fixed = Set<UUID>()
        fixed.reserveCapacity(points.count)
        for point in points where !(type(of: point) == movablePoint) {
            fixed.insert(point.id)
        }
        return fixed
    }

    static func shouldDetachFixedEndpoint(
        for delta: CGVector,
        orientation: ConnectionSegmentOrientation,
        tolerance: CGFloat
    ) -> Bool {
        guard orientation != .arbitrary else { return true }

        let length = hypot(delta.dx, delta.dy)
        if length <= tolerance {
            return false
        }

        guard let direction = orientation.direction else { return true }
        let cross = abs(delta.dx * direction.dy - delta.dy * direction.dx)
        return cross > tolerance
    }

    static func applyConstraints(
        movedIDs: [UUID],
        positions: inout [UUID: CGPoint],
        originalPositions: [UUID: CGPoint],
        adjacency: [UUID: [UUID]],
        orientations: [UUID: ConnectionSegmentOrientation],
        linkEndpoints: [UUID: (UUID, UUID)],
        fixedPointIDs: Set<UUID>,
        anchoredIDs: Set<UUID> = []
    ) {
        var queue = movedIDs
        var queued = Set(movedIDs)

        while let currentID = queue.first {
            queue.removeFirst()
            queued.remove(currentID)

            guard let currentPos = positions[currentID] else { continue }

            for linkID in adjacency[currentID] ?? [] {
                guard let orientation = orientations[linkID],
                    let endpoints = linkEndpoints[linkID]
                else { continue }

                let (aID, bID) = endpoints
                let otherID = (aID == currentID) ? bID : aID
                guard otherID != currentID,
                    let otherOrig = originalPositions[otherID]
                else { continue }

                if fixedPointIDs.contains(otherID) {
                    guard !anchoredIDs.contains(currentID),
                        let alignedCurrent = projected(
                            point: currentPos,
                            ontoLineThrough: otherOrig,
                            orientation: orientation
                        )
                    else { continue }

                    if positions[currentID] != alignedCurrent {
                        positions[currentID] = alignedCurrent
                    }
                    continue
                }

                let candidate = positions[otherID] ?? otherOrig
                guard
                    let projectedOther = projected(
                        point: candidate,
                        ontoLineThrough: currentPos,
                        orientation: orientation
                    )
                else { continue }

                if positions[otherID] != projectedOther {
                    positions[otherID] = projectedOther
                    if !queued.contains(otherID) {
                        queue.append(otherID)
                        queued.insert(otherID)
                    }
                }
            }
        }
    }

    static func projected(
        point: CGPoint,
        ontoLineThrough anchor: CGPoint,
        orientation: ConnectionSegmentOrientation
    ) -> CGPoint? {
        guard let direction = orientation.direction else { return nil }
        let offset = CGVector(dx: point.x - anchor.x, dy: point.y - anchor.y)
        let dot = offset.dx * direction.dx + offset.dy * direction.dy
        return CGPoint(
            x: anchor.x + direction.dx * dot,
            y: anchor.y + direction.dy * dot
        )
    }
}
