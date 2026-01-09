import CoreGraphics
import Foundation

struct ManhattanNormalizationState {
    var pointsByID: [UUID: CGPoint]
    let pointsByObject: [UUID: any ConnectionPoint]
    var links: [WireSegment]
    var removedPointIDs: Set<UUID>
    var removedLinkIDs: Set<UUID>
    let epsilon: CGFloat
    let preferredIDs: Set<UUID>
}
