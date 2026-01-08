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
        let epsilon = max(0.5 / max(context.magnification, 0.0001), 0.0001)
        var pointsByID = Dictionary(
            uniqueKeysWithValues: points.map { ($0.id, context.snapPoint($0.position)) }
        )
        let pointsByObject = Dictionary(
            uniqueKeysWithValues: points.map { ($0.id, $0) }
        )
        let originalLinksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })

        var normalizedLinks = links.map { WireSegment(id: $0.id, startID: $0.startID, endID: $0.endID) }
        let mergeDelta = mergeCoincidentPoints(
            pointsByID: &pointsByID,
            pointsByObject: pointsByObject,
            links: &normalizedLinks,
            epsilon: epsilon
        )

        var updatesByID: [UUID: WireSegment] = [:]
        updatesByID.reserveCapacity(normalizedLinks.count)
        for link in normalizedLinks {
            if let original = originalLinksByID[link.id],
               (original.startID != link.startID || original.endID != link.endID) {
                updatesByID[link.id] = link
            }
        }

        var addedLinks: [WireSegment] = []

        for link in normalizedLinks {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else { continue }

            let mids = splitPoints(
                on: link,
                start: start,
                end: end,
                pointsByID: pointsByID,
                pointsByObject: pointsByObject,
                epsilon: epsilon
            )
            if mids.isEmpty { continue }

            let chain = [link.startID] + mids + [link.endID]
            guard chain.count >= 3 else { continue }

            let first = WireSegment(id: link.id, startID: chain[0], endID: chain[1])
            updatesByID[link.id] = first

            for i in 1..<(chain.count - 1) {
                addedLinks.append(WireSegment(startID: chain[i], endID: chain[i + 1]))
            }
        }

        var workingLinks: [WireSegment] = []
        workingLinks.reserveCapacity(normalizedLinks.count + addedLinks.count)
        for link in normalizedLinks {
            workingLinks.append(updatesByID[link.id] ?? link)
        }
        workingLinks.append(contentsOf: addedLinks)

        let collapseDelta = collapseColinearPoints(
            links: &workingLinks,
            pointsByID: pointsByID,
            pointsByObject: pointsByObject,
            epsilon: epsilon,
            preferredIDs: Set(originalLinksByID.keys)
        )

        let mergeRemoved = removeDuplicateLinks(
            links: &workingLinks,
            preferredIDs: Set(originalLinksByID.keys)
        )

        let finalIDs = Set(workingLinks.map { $0.id })
        var removedLinkIDs = mergeDelta.removedLinkIDs
        removedLinkIDs.formUnion(collapseDelta.removedLinkIDs)
        removedLinkIDs.formUnion(mergeRemoved)
        removedLinkIDs.formUnion(Set(originalLinksByID.keys).subtracting(finalIDs))

        var updatedLinks: [any CanvasItem & ConnectionLink] = []
        var addedLinksOut: [any CanvasItem & ConnectionLink] = []
        for link in workingLinks {
            if let original = originalLinksByID[link.id] {
                if original.startID != link.startID || original.endID != link.endID {
                    updatedLinks.append(link)
                }
            } else {
                addedLinksOut.append(link)
            }
        }

        let removedPointIDs = mergeDelta.removedPointIDs.union(collapseDelta.removedPointIDs)
        if removedPointIDs.isEmpty
            && removedLinkIDs.isEmpty
            && updatedLinks.isEmpty
            && addedLinksOut.isEmpty {
            return ConnectionDelta()
        }

        return ConnectionDelta(
            removedPointIDs: removedPointIDs,
            updatedPoints: [],
            addedPoints: [],
            removedLinkIDs: removedLinkIDs,
            updatedLinks: updatedLinks,
            addedLinks: addedLinksOut
        )
    }

    private func splitPoints(
        on link: any ConnectionLink,
        start: CGPoint,
        end: CGPoint,
        pointsByID: [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        epsilon: CGFloat
    ) -> [UUID] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len2 = max(dx * dx + dy * dy, epsilon * epsilon)

        var mids: [(id: UUID, t: CGFloat)] = []
        mids.reserveCapacity(pointsByID.count)

        for (id, point) in pointsByID where id != link.startID && id != link.endID {
            guard let pointObj = pointsByObject[id], !(pointObj is WireVertex) else { continue }
            if isPoint(point, onSegmentBetween: start, p2: end, tol: epsilon) {
                let t = ((point.x - start.x) * dx + (point.y - start.y) * dy) / len2
                mids.append((id: id, t: t))
            }
        }

        if mids.isEmpty {
            return []
        }

        mids.sort { $0.t < $1.t }
        var ordered: [UUID] = []
        ordered.reserveCapacity(mids.count)
        var lastPoint = start

        for entry in mids {
            guard let point = pointsByID[entry.id] else { continue }
            if hypot(point.x - lastPoint.x, point.y - lastPoint.y) <= epsilon { continue }
            ordered.append(entry.id)
            lastPoint = point
        }

        return ordered
    }

    private func isPoint(
        _ p: CGPoint,
        onSegmentBetween a: CGPoint,
        p2 b: CGPoint,
        tol: CGFloat
    ) -> Bool {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) <= tol }
        let cross = (p.x - a.x) * dy - (p.y - a.y) * dx
        if abs(cross) > tol * sqrt(len2) { return false }
        let dot = (p.x - a.x) * dx + (p.y - a.y) * dy
        if dot < -tol || dot > len2 + tol { return false }
        return true
    }

    private struct MergeDelta {
        let removedPointIDs: Set<UUID>
        let removedLinkIDs: Set<UUID>
    }

    private func collapseColinearPoints(
        links: inout [WireSegment],
        pointsByID: [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        epsilon: CGFloat,
        preferredIDs: Set<UUID>
    ) -> MergeDelta {
        var linksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        var removedPoints = Set<UUID>()
        var removedLinks = Set<UUID>()
        var changed = true

        while changed {
            changed = false

            var adjacency: [UUID: [UUID]] = [:]
            adjacency.reserveCapacity(pointsByID.count)
            for link in linksByID.values {
                adjacency[link.startID, default: []].append(link.id)
                adjacency[link.endID, default: []].append(link.id)
            }

            for (pointID, pointObj) in pointsByObject {
                guard pointObj is WireVertex else { continue }
                guard removedPoints.contains(pointID) == false else { continue }
                guard let point = pointsByID[pointID] else { continue }
                let incident = adjacency[pointID] ?? []
                if incident.isEmpty {
                    if pointIsCoveredByAnyLink(
                        point: point,
                        linksByID: linksByID,
                        pointsByID: pointsByID,
                        epsilon: epsilon
                    ) {
                        removedPoints.insert(pointID)
                        changed = true
                    }
                    continue
                }
                if incident.count >= 3 { continue }

                if incident.count == 2 {
                    guard
                        let linkA = linksByID[incident[0]],
                        let linkB = linksByID[incident[1]]
                    else { continue }

                    let neighborA = otherEndpoint(of: linkA, at: pointID)
                    let neighborB = otherEndpoint(of: linkB, at: pointID)
                    guard
                        let posA = pointsByID[neighborA],
                        let posB = pointsByID[neighborB]
                    else { continue }

                    guard isPoint(point, onSegmentBetween: posA, p2: posB, tol: epsilon) else { continue }

                    let keepID = selectKeepID(from: incident, preferred: preferredIDs)
                    linksByID[keepID] = WireSegment(id: keepID, startID: neighborA, endID: neighborB)
                    for id in incident where id != keepID {
                        linksByID.removeValue(forKey: id)
                        removedLinks.insert(id)
                    }
                    removedPoints.insert(pointID)
                    changed = true
                    continue
                }

                if incident.count == 1 {
                    guard let link = linksByID[incident[0]] else { continue }

                    if pointIsCoveredByOtherLink(
                        pointID: pointID,
                        point: point,
                        excluding: link.id,
                        linksByID: linksByID,
                        pointsByID: pointsByID,
                        epsilon: epsilon
                    ) {
                        linksByID.removeValue(forKey: link.id)
                        removedLinks.insert(link.id)
                        removedPoints.insert(pointID)
                        changed = true
                    }
                }
            }
        }

        links = Array(linksByID.values)
        return MergeDelta(removedPointIDs: removedPoints, removedLinkIDs: removedLinks)
    }

    private func otherEndpoint(of link: WireSegment, at pointID: UUID) -> UUID {
        link.startID == pointID ? link.endID : link.startID
    }

    private func pointIsCoveredByOtherLink(
        pointID: UUID,
        point: CGPoint,
        excluding excludedID: UUID,
        linksByID: [UUID: WireSegment],
        pointsByID: [UUID: CGPoint],
        epsilon: CGFloat
    ) -> Bool {
        for (id, link) in linksByID where id != excludedID {
            guard link.startID != pointID && link.endID != pointID else { continue }
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else { continue }
            if isPoint(point, onSegmentBetween: start, p2: end, tol: epsilon) {
                return true
            }
        }
        return false
    }

    private func pointIsCoveredByAnyLink(
        point: CGPoint,
        linksByID: [UUID: WireSegment],
        pointsByID: [UUID: CGPoint],
        epsilon: CGFloat
    ) -> Bool {
        for link in linksByID.values {
            guard let start = pointsByID[link.startID],
                  let end = pointsByID[link.endID]
            else { continue }
            if isPoint(point, onSegmentBetween: start, p2: end, tol: epsilon) {
                return true
            }
        }
        return false
    }

    private func mergeCoincidentPoints(
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        links: inout [WireSegment],
        epsilon: CGFloat
    ) -> MergeDelta {
        var buckets: [PositionKey: [UUID]] = [:]
        buckets.reserveCapacity(pointsByID.count)
        for (id, point) in pointsByID {
            buckets[PositionKey(position: point, epsilon: epsilon), default: []].append(id)
        }

        var removedPoints = Set<UUID>()

        for ids in buckets.values where ids.count > 1 {
            let survivor = selectSurvivor(from: ids, pointsByObject: pointsByObject)
            for id in ids where id != survivor {
                rewireLinks(from: id, to: survivor, links: &links)
                pointsByID.removeValue(forKey: id)
                removedPoints.insert(id)
            }
        }

        var removedLinkIDs = Set<UUID>()
        links.removeAll { link in
            if link.startID == link.endID {
                removedLinkIDs.insert(link.id)
                return true
            }
            return false
        }

        return MergeDelta(removedPointIDs: removedPoints, removedLinkIDs: removedLinkIDs)
    }

    private func selectSurvivor(
        from ids: [UUID],
        pointsByObject: [UUID: any ConnectionPoint]
    ) -> UUID {
        for id in ids {
            if let point = pointsByObject[id], !(point is WireVertex) {
                return id
            }
        }
        return ids.sorted { $0.uuidString < $1.uuidString }.first ?? ids.first ?? UUID()
    }

    private func rewireLinks(
        from victim: UUID,
        to survivor: UUID,
        links: inout [WireSegment]
    ) {
        for index in links.indices {
            var link = links[index]
            if link.startID == victim {
                link.startID = survivor
            }
            if link.endID == victim {
                link.endID = survivor
            }
            links[index] = link
        }
    }

    private func removeDuplicateLinks(
        links: inout [WireSegment],
        preferredIDs: Set<UUID>
    ) -> Set<UUID> {
        struct LinkKey: Hashable {
            let a: UUID
            let b: UUID

            init(_ start: UUID, _ end: UUID) {
                if start.uuidString <= end.uuidString {
                    a = start
                    b = end
                } else {
                    a = end
                    b = start
                }
            }
        }

        var keepByKey: [LinkKey: WireSegment] = [:]
        keepByKey.reserveCapacity(links.count)
        var removed = Set<UUID>()

        for link in links {
            let key = LinkKey(link.startID, link.endID)
            if let existing = keepByKey[key] {
                let keepID = selectKeepID(from: [existing.id, link.id], preferred: preferredIDs)
                if keepID == existing.id {
                    removed.insert(link.id)
                } else {
                    removed.insert(existing.id)
                    keepByKey[key] = link
                }
            } else {
                keepByKey[key] = link
            }
        }

        links = Array(keepByKey.values)
        return removed
    }

    private func selectKeepID(from ids: [UUID], preferred: Set<UUID>) -> UUID {
        for id in ids where preferred.contains(id) {
            return id
        }
        return ids.first ?? UUID()
    }

    private struct PositionKey: Hashable {
        let x: Int
        let y: Int

        init(position: CGPoint, epsilon: CGFloat) {
            x = Int((position.x / epsilon).rounded())
            y = Int((position.y / epsilon).rounded())
        }
    }
}
