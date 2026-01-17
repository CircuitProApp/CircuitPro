import CoreGraphics
import Foundation

struct TraceCollapseLinearRunsRule {
    func apply(to state: inout TraceNormalizationState) {
        var linksByID = Dictionary(uniqueKeysWithValues: state.links.map { ($0.id, $0) })
        var removedPoints = Set<UUID>()
        var removedLinks = Set<UUID>()
        var changed = true

        while changed {
            changed = false
            let adjacency = buildAdjacency(from: linksByID)
            let pointIDs = Array(state.pointsByID.keys)

            runLoop: for pointID in pointIDs {
                guard let startPoint = state.pointsByID[pointID] else { continue }
                guard isProtected(pointID, state: state, adjacency: adjacency, linksByID: linksByID) == false
                else { continue }
                let seeds = uniqueIncidentSeeds(
                    from: pointID,
                    pointsByID: state.pointsByID,
                    linksByID: linksByID,
                    adjacency: adjacency,
                    epsilon: state.epsilon
                )

                for seed in seeds {
                    if processRun(
                        from: pointID,
                        startPoint: startPoint,
                        baseDir: seed.dir,
                        width: seed.width,
                        layerId: seed.layerId,
                        state: &state,
                        linksByID: &linksByID,
                        adjacency: adjacency,
                        removedPoints: &removedPoints,
                        removedLinks: &removedLinks
                    ) {
                        changed = true
                        break runLoop
                    }
                }
            }

            if removeOverlappingOrphans(
                state: &state,
                linksByID: &linksByID,
                removedPoints: &removedPoints,
                removedLinks: &removedLinks
            ) {
                changed = true
            }
        }

        state.links = Array(linksByID.values)
        state.removedPointIDs.formUnion(removedPoints)
        state.removedLinkIDs.formUnion(removedLinks)
    }

    private struct RunSeed {
        let dir: CGVector
        let width: CGFloat
        let layerId: UUID
    }

    private struct TraceMetadataKey: Hashable {
        let width: CGFloat
        let layerId: UUID
    }

    private func buildAdjacency(from linksByID: [UUID: TraceSegment]) -> [UUID: [UUID]] {
        var adjacency: [UUID: [UUID]] = [:]
        for link in linksByID.values {
            adjacency[link.startID, default: []].append(link.id)
            adjacency[link.endID, default: []].append(link.id)
        }
        return adjacency
    }

    private func isProtected(
        _ pointID: UUID,
        state: TraceNormalizationState,
        adjacency: [UUID: [UUID]],
        linksByID: [UUID: TraceSegment]
    ) -> Bool {
        if let point = state.pointsByObject[pointID], !(point is TraceVertex) {
            return true
        }
        guard let edgeIDs = adjacency[pointID], !edgeIDs.isEmpty else { return false }
        var seen: TraceMetadataKey?
        for edgeID in edgeIDs {
            guard let edge = linksByID[edgeID] else { continue }
            let key = TraceMetadataKey(width: edge.width, layerId: edge.layerId)
            if let existing = seen {
                if existing != key {
                    return true
                }
            } else {
                seen = key
            }
        }
        return false
    }

    private func uniqueIncidentSeeds(
        from pointID: UUID,
        pointsByID: [UUID: CGPoint],
        linksByID: [UUID: TraceSegment],
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
                    && $0.width == edge.width
                    && $0.layerId == edge.layerId
            }) {
                out.append(RunSeed(dir: dir, width: edge.width, layerId: edge.layerId))
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
        baseDir: CGVector,
        width: CGFloat,
        layerId: UUID,
        state: inout TraceNormalizationState,
        linksByID: inout [UUID: TraceSegment],
        adjacency: [UUID: [UUID]],
        removedPoints: inout Set<UUID>,
        removedLinks: inout Set<UUID>
    ) -> Bool {
        var run: [UUID] = []
        var stack = [startID]
        var seen: Set<UUID> = [startID]

        while let vid = stack.popLast() {
            guard let vPoint = state.pointsByID[vid] else { continue }
            run.append(vid)
            for edgeID in adjacency[vid] ?? [] {
                guard let edge = linksByID[edgeID] else { continue }
                guard edge.width == width, edge.layerId == layerId else { continue }
                let neighborID = edge.startID == vid ? edge.endID : edge.startID
                guard let neighborPoint = state.pointsByID[neighborID] else { continue }
                guard isOnLine(a: startPoint, dir: baseDir, p: neighborPoint, tol: state.epsilon) else { continue }
                if seen.contains(neighborID) { continue }
                seen.insert(neighborID)
                stack.append(neighborID)
            }
        }

        if run.count < 3 { return false }

        let denom = max(baseDir.dx * baseDir.dx + baseDir.dy * baseDir.dy, state.epsilon * state.epsilon)
        func t(_ p: CGPoint) -> CGFloat {
            ((p.x - startPoint.x) * baseDir.dx + (p.y - startPoint.y) * baseDir.dy) / denom
        }

        run.sort {
            guard let p0 = state.pointsByID[$0], let p1 = state.pointsByID[$1] else { return false }
            return t(p0) < t(p1)
        }

        let runIDs = Set(run)
        struct SpanEdge {
            let id: UUID
            let tMin: CGFloat
            let tMax: CGFloat
            let startID: UUID
            let endID: UUID
        }

        var edgesOnRun: [SpanEdge] = []
        edgesOnRun.reserveCapacity(run.count)
        for (edgeID, edge) in linksByID {
            guard edge.width == width, edge.layerId == layerId else { continue }
            guard runIDs.contains(edge.startID), runIDs.contains(edge.endID) else { continue }
            guard let p1 = state.pointsByID[edge.startID],
                  let p2 = state.pointsByID[edge.endID],
                  isOnLine(a: startPoint, dir: baseDir, p: p1, tol: state.epsilon),
                  isOnLine(a: startPoint, dir: baseDir, p: p2, tol: state.epsilon)
            else { continue }
            let t1 = t(p1)
            let t2 = t(p2)
            edgesOnRun.append(
                SpanEdge(id: edgeID, tMin: min(t1, t2), tMax: max(t1, t2), startID: edge.startID, endID: edge.endID)
            )
        }
        if edgesOnRun.isEmpty { return false }

        var keep: Set<UUID> = []
        for vid in run {
            if isProtected(vid, state: state, adjacency: adjacency, linksByID: linksByID) {
                keep.insert(vid)
                continue
            }

            let incidentEdges = adjacency[vid] ?? []
            let deg = incidentEdges.count
            var collinearDeg = 0
            for edgeID in incidentEdges {
                guard let edge = linksByID[edgeID] else { continue }
                guard edge.width == width, edge.layerId == layerId else { continue }
                let neighborID = edge.startID == vid ? edge.endID : edge.startID
                guard let neighborPoint = state.pointsByID[neighborID],
                      let vPoint = state.pointsByID[vid]
                else { continue }
                if isOnLine(a: vPoint, dir: baseDir, p: neighborPoint, tol: state.epsilon) {
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

        var runEdgeIDs = Set(edgesOnRun.map { $0.id })
        for vid in run where !keep.contains(vid) {
            let remaining = (adjacency[vid] ?? []).filter { !runEdgeIDs.contains($0) }
            if remaining.isEmpty {
                state.pointsByID.removeValue(forKey: vid)
                removedPoints.insert(vid)
            }
        }

        let keptVerts = run.filter { keep.contains($0) }
        if keptVerts.count >= 2 {
            for i in 0..<(keptVerts.count - 1) {
                let vA = keptVerts[i]
                let vB = keptVerts[i + 1]
                guard let pointA = state.pointsByID[vA],
                      let pointB = state.pointsByID[vB]
                else { continue }
                let tA = t(pointA)
                let tB = t(pointB)
                let lo = min(tA, tB) - 10 * state.epsilon
                let hi = max(tA, tB) + 10 * state.epsilon

                let candidates = edgesOnRun.filter { $0.tMin >= lo && $0.tMax <= hi }
                let fallback = candidates.isEmpty
                    ? edgesOnRun.filter { $0.tMax >= lo && $0.tMin <= hi }
                    : candidates
                let candidateIDs = fallback.map { $0.id }.filter { runEdgeIDs.contains($0) }
                let keepID = candidateIDs.isEmpty
                    ? UUID()
                    : selectKeepID(from: candidateIDs, preferred: state.preferredIDs)

                if !hasLink(
                    between: vA,
                    and: vB,
                    width: width,
                    layerId: layerId,
                    linksByID: linksByID,
                    excluding: runEdgeIDs
                ) {
                    linksByID[keepID] = TraceSegment(
                        id: keepID,
                        startID: vA,
                        endID: vB,
                        width: width,
                        layerId: layerId
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
        state: inout TraceNormalizationState,
        linksByID: inout [UUID: TraceSegment],
        removedPoints: inout Set<UUID>,
        removedLinks: inout Set<UUID>
    ) -> Bool {
        let adjacency = buildAdjacency(from: linksByID)
        var changed = false

        for (pointID, _) in state.pointsByObject {
            guard let point = state.pointsByID[pointID] else { continue }
            let incident = adjacency[pointID] ?? []

            if incident.isEmpty {
                if pointIsCoveredByAnyLink(
                    point: point,
                    linksByID: linksByID,
                    pointsByID: state.pointsByID,
                    epsilon: state.epsilon
                ) {
                    state.pointsByID.removeValue(forKey: pointID)
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
                    width: link.width,
                    layerId: link.layerId,
                    linksByID: linksByID,
                    pointsByID: state.pointsByID,
                    epsilon: state.epsilon
                ) {
                    linksByID.removeValue(forKey: link.id)
                    removedLinks.insert(link.id)
                    state.pointsByID.removeValue(forKey: pointID)
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
        width: CGFloat,
        layerId: UUID,
        linksByID: [UUID: TraceSegment],
        excluding excludedIDs: Set<UUID>
    ) -> Bool {
        for (id, link) in linksByID where !excludedIDs.contains(id) {
            guard link.width == width, link.layerId == layerId else { continue }
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
        width: CGFloat,
        layerId: UUID,
        linksByID: [UUID: TraceSegment],
        pointsByID: [UUID: CGPoint],
        epsilon: CGFloat
    ) -> Bool {
        for (id, link) in linksByID where id != excludedID {
            guard link.width == width, link.layerId == layerId else { continue }
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
        linksByID: [UUID: TraceSegment],
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
