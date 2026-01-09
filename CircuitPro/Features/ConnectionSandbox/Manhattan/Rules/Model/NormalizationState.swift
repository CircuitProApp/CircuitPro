import CoreGraphics
import Foundation

struct NormalizationState {
    var pointsByID: [UUID: CGPoint]
    let pointsByObject: [UUID: any ConnectionPoint]
    var links: [WireSegment]
    var addedPoints: [WireVertex]
    var removedPointIDs: Set<UUID>
    var removedLinkIDs: Set<UUID>
    let epsilon: CGFloat
    let preferredIDs: Set<UUID>

    mutating func appendLinkIfMissing(startID: UUID, endID: UUID, preferredID: UUID? = nil) {
        if hasLink(between: startID, and: endID) {
            return
        }
        if let preferredID {
            links.append(WireSegment(id: preferredID, startID: startID, endID: endID))
        } else {
            links.append(WireSegment(startID: startID, endID: endID))
        }
    }

    func hasLink(between a: UUID, and b: UUID) -> Bool {
        for link in links {
            if (link.startID == a && link.endID == b)
                || (link.startID == b && link.endID == a) {
                return true
            }
        }
        return false
    }
}
