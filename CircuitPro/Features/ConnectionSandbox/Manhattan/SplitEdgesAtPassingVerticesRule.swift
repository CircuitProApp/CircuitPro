import CoreGraphics
import Foundation

struct SplitEdgesAtPassingVerticesRule: ManhattanNormalizationRule {
    func apply(to state: inout ManhattanNormalizationState) {
        let originalCount = state.links.count
        guard originalCount > 0 else { return }

        var added: [WireSegment] = []

        for index in 0..<originalCount {
            let link = state.links[index]
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
            if mids.isEmpty { continue }

            let chain = [link.startID] + mids + [link.endID]
            guard chain.count >= 3 else { continue }

            state.links[index] = WireSegment(id: link.id, startID: chain[0], endID: chain[1])
            for i in 1..<(chain.count - 1) {
                added.append(WireSegment(startID: chain[i], endID: chain[i + 1]))
            }
        }

        if !added.isEmpty {
            state.links.append(contentsOf: added)
        }
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
