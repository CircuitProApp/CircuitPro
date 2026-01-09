import CoreGraphics
import Foundation

struct SplitEdgesAtPassingVerticesRule: NormalizationRule {
    func apply(to state: inout NormalizationState) {
        guard !state.links.isEmpty else { return }

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

        var newLinks: [WireSegment] = []
        newLinks.reserveCapacity(state.links.count)
        var seen = Set<LinkKey>()

        func appendLink(startID: UUID, endID: UUID, id: UUID?) -> Bool {
            let key = LinkKey(startID, endID)
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            if let id {
                newLinks.append(WireSegment(id: id, startID: startID, endID: endID))
            } else {
                newLinks.append(WireSegment(startID: startID, endID: endID))
            }
            return true
        }

        let originalLinks = state.links
        for link in originalLinks {
            guard let start = state.pointsByID[link.startID],
                  let end = state.pointsByID[link.endID]
            else { continue }

            let mids = splitPoints(
                on: link,
                start: start,
                end: end,
                pointsByID: state.pointsByID,
                pointsByObject: state.pointsByObject,
                epsilon: state.epsilon
            )
            if mids.isEmpty {
                if !appendLink(startID: link.startID, endID: link.endID, id: link.id) {
                    state.removedLinkIDs.insert(link.id)
                }
                continue
            }

            let chain = [link.startID] + mids + [link.endID]
            guard chain.count >= 3 else { continue }

            if !appendLink(startID: chain[0], endID: chain[1], id: link.id) {
                state.removedLinkIDs.insert(link.id)
            }
            for i in 1..<(chain.count - 1) {
                _ = appendLink(startID: chain[i], endID: chain[i + 1], id: nil)
            }
        }

        state.links = newLinks
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
            guard pointsByObject[id] != nil else { continue }
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
}
