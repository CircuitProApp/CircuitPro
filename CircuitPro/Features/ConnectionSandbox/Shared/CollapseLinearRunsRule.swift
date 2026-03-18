import CoreGraphics
import Foundation

struct CollapseLinearRunsRule<Link: SharedNormalizationLink, FreePoint> {
    private struct SpanEdge {
        let id: UUID
        let tMin: CGFloat
        let tMax: CGFloat
    }

    func apply(
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        links: inout [Link],
        removedPointIDs: inout Set<UUID>,
        removedLinkIDs: inout Set<UUID>,
        epsilon: CGFloat,
        preferredIDs: Set<UUID>
    ) {
        var linksByID = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        var removedPoints = Set<UUID>()
        var removedLinks = Set<UUID>()
        var changed = true

        while changed {
            changed = false
            let adjacency = buildAdjacency(from: linksByID)
            let pointIDs = Array(pointsByID.keys)

            runLoop: for pointID in pointIDs {
                guard let startPoint = pointsByID[pointID] else { continue }
                guard
                    isProtected(
                        pointID,
                        pointsByObject: pointsByObject,
                        adjacency: adjacency,
                        linksByID: linksByID
                    ) == false
                else { continue }
                let seeds = uniqueIncidentSeeds(
                    from: pointID,
                    pointsByID: pointsByID,
                    linksByID: linksByID,
                    adjacency: adjacency,
                    epsilon: epsilon
                )

                for seed in seeds {
                    if processRun(
                        from: pointID,
                        startPoint: startPoint,
                        seed: seed,
                        pointsByID: &pointsByID,
                        pointsByObject: pointsByObject,
                        linksByID: &linksByID,
                        adjacency: adjacency,
                        removedPoints: &removedPoints,
                        removedLinks: &removedLinks,
                        epsilon: epsilon,
                        preferredIDs: preferredIDs
                    ) {
                        changed = true
                        break runLoop
                    }
                }
            }

            if removeOverlappingOrphans(
                pointsByID: &pointsByID,
                pointsByObject: pointsByObject,
                linksByID: &linksByID,
                removedPoints: &removedPoints,
                removedLinks: &removedLinks,
                epsilon: epsilon
            ) {
                changed = true
            }
        }

        links = Array(linksByID.values)
        removedPointIDs.formUnion(removedPoints)
        removedLinkIDs.formUnion(removedLinks)
    }

    private struct RunSeed: Hashable {
        let dir: CGVector
        let metadata: Link.Metadata

        func hash(into hasher: inout Hasher) {
            hasher.combine(dir.dx)
            hasher.combine(dir.dy)
            hasher.combine(metadata)
        }

        static func == (lhs: RunSeed, rhs: RunSeed) -> Bool {
            lhs.dir.dx == rhs.dir.dx
                && lhs.dir.dy == rhs.dir.dy
                && lhs.metadata == rhs.metadata
        }
    }

    private func buildAdjacency(from linksByID: [UUID: Link]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in linksByID.values {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    private func isProtected(
        _ pointID: UUID,
        pointsByObject: [UUID: any ConnectionPoint],
        adjacency: [UUID: [UUID]],
        linksByID: [UUID: Link]
    ) -> Bool {
        if let point = pointsByObject[pointID], !(point is FreePoint) {
            return true
        }
        guard let edgeIDs = adjacency[pointID], !edgeIDs.isEmpty else { return false }
        var seen: Link.Metadata?
        for edgeID in edgeIDs {
            guard let edge = linksByID[edgeID] else { continue }
            let metadata = edge.normalizationMetadata
            if let existing = seen {
                if existing != metadata {
                    return true
                }
            } else {
                seen = metadata
            }
        }
        return false
    }

    private func uniqueIncidentSeeds(
        from pointID: UUID,
        pointsByID: [UUID: CGPoint],
        linksByID: [UUID: Link],
        adjacency: [UUID: [UUID]],
        epsilon: CGFloat
    ) -> [RunSeed] {
        guard let origin = pointsByID[pointID],
            let edgeIDs = adjacency[pointID]
        else { return [] }

        var out: [RunSeed] = []
        out.reserveCapacity(edgeIDs.count)

        for edgeID in edgeIDs {
            guard let edge = linksByID[edgeID] else { continue }
            let neighborID = edge.startID == pointID ? edge.endID : edge.startID
            guard let neighbor = pointsByID[neighborID] else { continue }
            let dx = neighbor.x - origin.x
            let dy = neighbor.y - origin.y
            let len = hypot(dx, dy)
            if len <= epsilon { continue }
            let dir = CGVector(dx: dx / len, dy: dy / len)
            if !out.contains(where: {
                approxSameDir($0.dir, dir, tol: epsilon)
                    && $0.metadata == edge.normalizationMetadata
            }) {
                out.append(RunSeed(dir: dir, metadata: edge.normalizationMetadata))
            }
        }
        return out
    }

    private func approxSameDir(_ a: CGVector, _ b: CGVector, tol: CGFloat) -> Bool {
        let dot = a.dx * b.dx + a.dy * b.dy
        return abs(abs(dot) - 1.0) <= 10 * tol
    }

    private func processRun(
        from startID: UUID,
        startPoint: CGPoint,
        seed: RunSeed,
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        linksByID: inout [UUID: Link],
        adjacency: [UUID: [UUID]],
        removedPoints: inout Set<UUID>,
        removedLinks: inout Set<UUID>,
        epsilon: CGFloat,
        preferredIDs: Set<UUID>
    ) -> Bool {
        var run: [UUID] = []
        var stack = [startID]
        var seen: Set<UUID> = [startID]

        while let vid = stack.popLast() {
            run.append(vid)
            for edgeID in adjacency[vid] ?? [] {
                guard let edge = linksByID[edgeID] else { continue }
                guard edge.normalizationMetadata == seed.metadata else { continue }
                let neighborID = edge.startID == vid ? edge.endID : edge.startID
                guard let neighborPoint = pointsByID[neighborID] else { continue }
                guard isOnLine(a: startPoint, dir: seed.dir, p: neighborPoint, tol: epsilon) else {
                    continue
                }
                if seen.contains(neighborID) { continue }
                seen.insert(neighborID)
                stack.append(neighborID)
            }
        }

        if run.count < 3 { return false }

        let denom = max(seed.dir.dx * seed.dir.dx + seed.dir.dy * seed.dir.dy, epsilon * epsilon)
        func t(_ p: CGPoint) -> CGFloat {
            ((p.x - startPoint.x) * seed.dir.dx + (p.y - startPoint.y) * seed.dir.dy) / denom
        }

        run.sort {
            guard let p0 = pointsByID[$0], let p1 = pointsByID[$1] else { return false }
            return t(p0) < t(p1)
        }

        let runIDs = Set(run)
        var edgesOnRun: [SpanEdge] = []
        edgesOnRun.reserveCapacity(run.count)
        for (edgeID, edge) in linksByID {
            guard edge.normalizationMetadata == seed.metadata else { continue }
            guard runIDs.contains(edge.startID), runIDs.contains(edge.endID) else { continue }
            guard let p1 = pointsByID[edge.startID],
                let p2 = pointsByID[edge.endID],
                isOnLine(a: startPoint, dir: seed.dir, p: p1, tol: epsilon),
                isOnLine(a: startPoint, dir: seed.dir, p: p2, tol: epsilon)
            else { continue }
            let t1 = t(p1)
            let t2 = t(p2)
            edgesOnRun.append(SpanEdge(id: edgeID, tMin: min(t1, t2), tMax: max(t1, t2)))
        }
        if edgesOnRun.isEmpty { return false }

        var keep: Set<UUID> = []
        for vid in run {
            if isProtected(
                vid,
                pointsByObject: pointsByObject,
                adjacency: adjacency,
                linksByID: linksByID
            ) {
                keep.insert(vid)
                continue
            }

            let incidentEdges = adjacency[vid] ?? []
            let deg = incidentEdges.count
            var collinearDeg = 0
            for edgeID in incidentEdges {
                guard let edge = linksByID[edgeID] else { continue }
                guard edge.normalizationMetadata == seed.metadata else { continue }
                let neighborID = edge.startID == vid ? edge.endID : edge.startID
                guard let neighborPoint = pointsByID[neighborID],
                    let vPoint = pointsByID[vid]
                else { continue }
                if isOnLine(a: vPoint, dir: seed.dir, p: neighborPoint, tol: epsilon) {
                    collinearDeg += 1
                }
            }
            if deg > collinearDeg {
                keep.insert(vid)
            }
        }

        if let first = run.first { keep.insert(first) }
        if let last = run.last { keep.insert(last) }
        if keep.count >= run.count { return false }

        var runEdgeIDs = Set(edgesOnRun.map(\.id))
        for vid in run where !keep.contains(vid) {
            let remaining = (adjacency[vid] ?? []).filter { !runEdgeIDs.contains($0) }
            if remaining.isEmpty {
                pointsByID.removeValue(forKey: vid)
                removedPoints.insert(vid)
            }
        }

        let keptVerts = run.filter { keep.contains($0) }
        if keptVerts.count >= 2 {
            for i in 0..<(keptVerts.count - 1) {
                let vA = keptVerts[i]
                let vB = keptVerts[i + 1]
                guard let pointA = pointsByID[vA],
                    let pointB = pointsByID[vB]
                else { continue }
                let tA = t(pointA)
                let tB = t(pointB)
                let lo = min(tA, tB) - 10 * epsilon
                let hi = max(tA, tB) + 10 * epsilon

                let candidates = edgesOnRun.filter { $0.tMin >= lo && $0.tMax <= hi }
                let fallback =
                    candidates.isEmpty
                    ? edgesOnRun.filter { $0.tMax >= lo && $0.tMin <= hi }
                    : candidates
                let candidateIDs = fallback.map(\.id).filter { runEdgeIDs.contains($0) }
                let keepID =
                    candidateIDs.isEmpty
                    ? UUID()
                    : selectKeepID(from: candidateIDs, preferred: preferredIDs)

                if !hasLink(
                    between: vA,
                    and: vB,
                    metadata: seed.metadata,
                    linksByID: linksByID,
                    excluding: runEdgeIDs
                ) {
                    linksByID[keepID] = Link(
                        id: keepID,
                        startID: vA,
                        endID: vB,
                        normalizationMetadata: seed.metadata
                    )
                    runEdgeIDs.remove(keepID)
                }
            }
        }

        for id in runEdgeIDs {
            linksByID.removeValue(forKey: id)
            removedLinks.insert(id)
        }

        return true
    }

    private func removeOverlappingOrphans(
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        linksByID: inout [UUID: Link],
        removedPoints: inout Set<UUID>,
        removedLinks: inout Set<UUID>,
        epsilon: CGFloat
    ) -> Bool {
        let adjacency = buildAdjacency(from: linksByID)
        var changed = false

        for (pointID, pointObj) in pointsByObject {
            guard pointObj is FreePoint else { continue }
            guard let point = pointsByID[pointID] else { continue }
            let incident = adjacency[pointID] ?? []

            if incident.isEmpty {
                if pointIsCoveredByAnyLink(
                    point: point,
                    linksByID: linksByID,
                    pointsByID: pointsByID,
                    epsilon: epsilon
                ) {
                    pointsByID.removeValue(forKey: pointID)
                    removedPoints.insert(pointID)
                    changed = true
                }
                continue
            }

            if incident.count == 1 {
                guard let link = linksByID[incident[0]] else { continue }
                if pointIsCoveredByOtherLink(
                    pointID: pointID,
                    point: point,
                    excluding: link.id,
                    metadata: link.normalizationMetadata,
                    linksByID: linksByID,
                    pointsByID: pointsByID,
                    epsilon: epsilon
                ) {
                    linksByID.removeValue(forKey: link.id)
                    removedLinks.insert(link.id)
                    pointsByID.removeValue(forKey: pointID)
                    removedPoints.insert(pointID)
                    changed = true
                }
            }
        }

        return changed
    }

    private func hasLink(
        between a: UUID,
        and b: UUID,
        metadata: Link.Metadata,
        linksByID: [UUID: Link],
        excluding excludedIDs: Set<UUID>
    ) -> Bool {
        for (id, link) in linksByID where !excludedIDs.contains(id) {
            guard link.normalizationMetadata == metadata else { continue }
            if (link.startID == a && link.endID == b) || (link.startID == b && link.endID == a) {
                return true
            }
        }
        return false
    }

    private func pointIsCoveredByOtherLink(
        pointID: UUID,
        point: CGPoint,
        excluding excludedID: UUID,
        metadata: Link.Metadata,
        linksByID: [UUID: Link],
        pointsByID: [UUID: CGPoint],
        epsilon: CGFloat
    ) -> Bool {
        for (id, link) in linksByID where id != excludedID {
            guard link.normalizationMetadata == metadata else { continue }
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
        linksByID: [UUID: Link],
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

    private func isOnLine(a: CGPoint, dir: CGVector, p: CGPoint, tol: CGFloat) -> Bool {
        let vx = p.x - a.x
        let vy = p.y - a.y
        let cross = dir.dx * vy - dir.dy * vx
        let scale = max(hypot(dir.dx, dir.dy), tol)
        return abs(cross) <= tol * scale
    }
}
