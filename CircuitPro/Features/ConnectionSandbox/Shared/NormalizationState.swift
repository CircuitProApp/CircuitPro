import CoreGraphics
import Foundation

struct NormalizationState<Point: ConnectionPoint, Link: ConnectionLink> {
    var pointsByID: [UUID: CGPoint]
    var pointsByObject: [UUID: any ConnectionPoint]
    var typedPointsByID: [UUID: Point]
    var links: [Link]
    var addedPoints: [Point]
    var removedPointIDs: Set<UUID>
    var removedLinkIDs: Set<UUID>
    let epsilon: CGFloat
    let preferredIDs: Set<UUID>

    mutating func appendLinkIfMissing(startID: UUID, endID: UUID, preferredID: UUID? = nil) {
        if hasLink(between: startID, and: endID) {
            return
        }
        guard let linkType = Link.self as? WireSegment.Type else { return }
        let link =
            if let preferredID {
                linkType.init(id: preferredID, startID: startID, endID: endID)
            } else {
                linkType.init(startID: startID, endID: endID)
            }
        links.append(link as! Link)
    }

    func hasLink(between a: UUID, and b: UUID) -> Bool {
        for link in links {
            if (link.startID == a && link.endID == b)
                || (link.startID == b && link.endID == a)
            {
                return true
            }
        }
        return false
    }
}
