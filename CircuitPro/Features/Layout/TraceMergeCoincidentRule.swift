import CoreGraphics
import Foundation

struct TraceMergeCoincidentRule {
    func apply(to state: inout TraceNormalizationState) {
        var buckets: [PositionKey: [UUID]] = [:]
        buckets.reserveCapacity(state.pointsByID.count)
        for (id, point) in state.pointsByID {
            buckets[PositionKey(position: point, epsilon: state.epsilon), default: []].append(id)
        }

        var removedPoints = Set<UUID>()
        var processed = Set<UUID>()

        for ids in buckets.values where ids.count > 1 {
            var remaining = ids
            while let currentID = remaining.popLast() {
                if processed.contains(currentID) { continue }
                guard let currentPoint = state.pointsByID[currentID] else { continue }

                var cluster = [currentID]
                var index = 0
                while index < remaining.count {
                    let otherID = remaining[index]
                    guard let otherPoint = state.pointsByID[otherID] else {
                        index += 1
                        continue
                    }
                    if hypot(currentPoint.x - otherPoint.x, currentPoint.y - otherPoint.y) < state.epsilon {
                        cluster.append(otherID)
                        remaining.remove(at: index)
                    } else {
                        index += 1
                    }
                }

                guard cluster.count > 1 else { continue }

                let survivor = selectSurvivor(from: cluster, pointsByObject: state.pointsByObject)
                processed.insert(survivor)

                for id in cluster where id != survivor {
                    rewireLinks(from: id, to: survivor, links: &state.links)
                    state.pointsByID.removeValue(forKey: id)
                    removedPoints.insert(id)
                    processed.insert(id)
                }
            }
        }

        var removedLinks = Set<UUID>()
        state.links.removeAll { link in
            if link.startID == link.endID {
                removedLinks.insert(link.id)
                return true
            }
            return false
        }

        state.removedPointIDs.formUnion(removedPoints)
        state.removedLinkIDs.formUnion(removedLinks)
    }

    private func rewireLinks(
        from victim: UUID,
        to survivor: UUID,
        links: inout [TraceSegment]
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

    private func selectSurvivor(
        from ids: [UUID],
        pointsByObject: [UUID: any ConnectionPoint]
    ) -> UUID {
        for id in ids {
            if let point = pointsByObject[id], !(point is TraceVertex) {
                return id
            }
        }
        return ids.sorted { $0.uuidString < $1.uuidString }.first ?? ids.first ?? UUID()
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
