import CoreGraphics
import Foundation

struct TraceSplitEdgesAtPassingVerticesRule {
    func apply(to state: inout TraceNormalizationState) {
        guard !state.links.isEmpty else { return }

        struct LinkKey: Hashable {
            let a: UUID
            let b: UUID
            let width: CGFloat
            let layerId: UUID

            init(start: UUID, end: UUID, width: CGFloat, layerId: UUID) {
                if start.uuidString <= end.uuidString {
                    a = start
                    b = end
                } else {
                    a = end
                    b = start
                }
                self.width = width
                self.layerId = layerId
            }
        }

        var newLinks: [TraceSegment] = []
        newLinks.reserveCapacity(state.links.count)
        var seen = Set<LinkKey>()

        func appendLink(startID: UUID, endID: UUID, link: TraceSegment, id: UUID?) -> Bool {
            let key = LinkKey(start: startID, end: endID, width: link.width, layerId: link.layerId)
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            let newID = id ?? UUID()
            newLinks.append(
                TraceSegment(
                    id: newID,
                    startID: startID,
                    endID: endID,
                    width: link.width,
                    layerId: link.layerId
                )
            )
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
                if !appendLink(startID: link.startID, endID: link.endID, link: link, id: link.id) {
                    state.removedLinkIDs.insert(link.id)
                }
                continue
            }

            let chain = [link.startID] + mids + [link.endID]
            guard chain.count >= 3 else { continue }

            if !appendLink(startID: chain[0], endID: chain[1], link: link, id: link.id) {
                state.removedLinkIDs.insert(link.id)
            }
            for i in 1..<(chain.count - 1) {
                _ = appendLink(startID: chain[i], endID: chain[i + 1], link: link, id: nil)
            }
        }

        state.links = newLinks
    }

    private func splitPoints(
        on link: TraceSegment,
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
