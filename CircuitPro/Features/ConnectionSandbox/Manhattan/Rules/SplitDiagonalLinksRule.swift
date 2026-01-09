import CoreGraphics
import Foundation

struct SplitDiagonalLinksRule: NormalizationRule {
    let preferHorizontalFirst: Bool

    func apply(to state: inout NormalizationState) {
        var newLinks: [WireSegment] = []
        newLinks.reserveCapacity(state.links.count * 2)
        var seen = Set<LinkKey>()

        for link in state.links {
            guard let start = state.pointsByID[link.startID],
                  let end = state.pointsByID[link.endID]
            else {
                append(link: link, to: &newLinks, seen: &seen, state: &state)
                continue
            }

            let dx = end.x - start.x
            let dy = end.y - start.y
            if abs(dx) <= state.epsilon || abs(dy) <= state.epsilon {
                append(link: link, to: &newLinks, seen: &seen, state: &state)
                continue
            }

            let corner = preferHorizontalFirst
                ? CGPoint(x: end.x, y: start.y)
                : CGPoint(x: start.x, y: end.y)
            let cornerID = resolveCornerID(at: corner, state: &state)

            if appendIfMissing(
                startID: link.startID,
                endID: cornerID,
                preferredID: link.id,
                to: &newLinks,
                seen: &seen
            ) == false {
                state.removedLinkIDs.insert(link.id)
            }
            _ = appendIfMissing(
                startID: cornerID,
                endID: link.endID,
                preferredID: nil,
                to: &newLinks,
                seen: &seen
            )
        }

        state.links = newLinks
    }

    private func resolveCornerID(at position: CGPoint, state: inout NormalizationState) -> UUID {
        if let existing = findPointID(at: position, in: state) {
            return existing
        }

        let vertex = WireVertex(position: position)
        state.pointsByID[vertex.id] = position
        state.addedPoints.append(vertex)
        return vertex.id
    }

    private func findPointID(at position: CGPoint, in state: NormalizationState) -> UUID? {
        for (id, point) in state.pointsByID {
            if hypot(point.x - position.x, point.y - position.y) <= state.epsilon {
                return id
            }
        }
        return nil
    }

    private struct LinkKey: Hashable {
        let a: UUID
        let b: UUID

        init(_ start: UUID, _ end: UUID) {
            if start.uuidString < end.uuidString {
                self.a = start
                self.b = end
            } else {
                self.a = end
                self.b = start
            }
        }
    }

    private func append(
        link: WireSegment,
        to links: inout [WireSegment],
        seen: inout Set<LinkKey>,
        state: inout NormalizationState
    ) {
        if appendIfMissing(
            startID: link.startID,
            endID: link.endID,
            preferredID: link.id,
            to: &links,
            seen: &seen
        ) == false {
            state.removedLinkIDs.insert(link.id)
        }
    }

    private func appendIfMissing(
        startID: UUID,
        endID: UUID,
        preferredID: UUID?,
        to links: inout [WireSegment],
        seen: inout Set<LinkKey>
    ) -> Bool {
        let key = LinkKey(startID, endID)
        guard !seen.contains(key) else { return false }
        seen.insert(key)
        if let preferredID {
            links.append(WireSegment(id: preferredID, startID: startID, endID: endID))
        } else {
            links.append(WireSegment(startID: startID, endID: endID))
        }
        return true
    }
}
