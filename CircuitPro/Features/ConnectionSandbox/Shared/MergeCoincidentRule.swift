import CoreGraphics
import Foundation

struct MergeCoincidentRule<Link: SharedNormalizationLink, FreePoint> {
    func apply(
        pointsByID: inout [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        links: inout [Link],
        removedPointIDs: inout Set<UUID>,
        removedLinkIDs: inout Set<UUID>,
        epsilon: CGFloat
    ) {
        var buckets: [PositionKey: [UUID]] = [:]
        buckets.reserveCapacity(pointsByID.count)
        for (id, point) in pointsByID {
            buckets[PositionKey(position: point, epsilon: epsilon), default: []].append(id)
        }
        let membership = buildMembership(from: links)

        var removedPoints = Set<UUID>()
        var processed = Set<UUID>()

        for ids in buckets.values where ids.count > 1 {
            var remaining = ids
            while let currentID = remaining.popLast() {
                if processed.contains(currentID) { continue }
                guard let currentPoint = pointsByID[currentID] else { continue }

                var cluster = [currentID]
                var index = 0
                while index < remaining.count {
                    let otherID = remaining[index]
                    guard let otherPoint = pointsByID[otherID] else {
                        index += 1
                        continue
                    }
                    if hypot(currentPoint.x - otherPoint.x, currentPoint.y - otherPoint.y)
                        < epsilon,
                        canMerge(currentID, otherID, membership: membership)
                    {
                        cluster.append(otherID)
                        remaining.remove(at: index)
                    } else {
                        index += 1
                    }
                }

                guard cluster.count > 1 else { continue }

                let survivor = selectSurvivor(
                    from: cluster,
                    pointsByObject: pointsByObject,
                    freePointType: FreePoint.self
                )
                processed.insert(survivor)

                for id in cluster where id != survivor {
                    rewireLinks(from: id, to: survivor, links: &links)
                    pointsByID.removeValue(forKey: id)
                    removedPoints.insert(id)
                    processed.insert(id)
                }
            }
        }

        var removedLinks = Set<UUID>()
        links.removeAll { link in
            if link.startID == link.endID {
                removedLinks.insert(link.id)
                return true
            }
            return false
        }

        removedPointIDs.formUnion(removedPoints)
        removedLinkIDs.formUnion(removedLinks)
    }

    private func rewireLinks(
        from victim: UUID,
        to survivor: UUID,
        links: inout [Link]
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

    private func buildMembership(from links: [Link]) -> [UUID: Set<Link.Metadata>] {
        var membership: [UUID: Set<Link.Metadata>] = [:]
        for link in links {
            membership[link.startID, default: []].insert(link.normalizationMetadata)
            membership[link.endID, default: []].insert(link.normalizationMetadata)
        }
        return membership
    }

    private func canMerge(
        _ lhs: UUID,
        _ rhs: UUID,
        membership: [UUID: Set<Link.Metadata>]
    ) -> Bool {
        let left = membership[lhs] ?? []
        let right = membership[rhs] ?? []
        if left.isEmpty || right.isEmpty {
            return true
        }
        return left == right
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
