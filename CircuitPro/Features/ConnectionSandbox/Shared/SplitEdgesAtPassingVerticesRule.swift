import CoreGraphics
import Foundation

struct SplitEdgesAtPassingVerticesRule<Link: SharedNormalizationLink> {
    let shouldSplitThroughPoint: (any ConnectionPoint, Link.Metadata) -> Bool

    func apply(
        pointsByID: [UUID: CGPoint],
        pointsByObject: [UUID: any ConnectionPoint],
        links: inout [Link],
        removedLinkIDs: inout Set<UUID>,
        epsilon: CGFloat
    ) {
        guard !links.isEmpty else { return }

        var newLinks: [Link] = []
        newLinks.reserveCapacity(links.count)
        var seen = Set<LinkKey<Link.Metadata>>()

        func appendLink(
            startID: UUID,
            endID: UUID,
            link: Link,
            id: UUID?
        ) -> Bool {
            let key = LinkKey(
                start: startID,
                end: endID,
                metadata: link.normalizationMetadata
            )
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            let newID = id ?? UUID()
            newLinks.append(
                Link(
                    id: newID,
                    startID: startID,
                    endID: endID,
                    normalizationMetadata: link.normalizationMetadata
                )
            )
            return true
        }

        let originalLinks = links
        for link in originalLinks {
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
            if mids.isEmpty {
                if !appendLink(startID: link.startID, endID: link.endID, link: link, id: link.id) {
                    removedLinkIDs.insert(link.id)
                }
                continue
            }

            let chain = [link.startID] + mids + [link.endID]
            guard chain.count >= 3 else { continue }

            if !appendLink(startID: chain[0], endID: chain[1], link: link, id: link.id) {
                removedLinkIDs.insert(link.id)
            }
            for i in 1..<(chain.count - 1) {
                _ = appendLink(startID: chain[i], endID: chain[i + 1], link: link, id: nil)
            }
        }

        links = newLinks
    }

    private func splitPoints(
        on link: Link,
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
            guard let pointObject = pointsByObject[id] else { continue }
            guard shouldSplitThroughPoint(pointObject, link.normalizationMetadata) else { continue }
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

    private struct LinkKey<Metadata: Hashable>: Hashable {
        let a: UUID
        let b: UUID
        let metadata: Metadata

        init(start: UUID, end: UUID, metadata: Metadata) {
            if start.uuidString <= end.uuidString {
                a = start
                b = end
            } else {
                a = end
                b = start
            }
            self.metadata = metadata
        }
    }
}
