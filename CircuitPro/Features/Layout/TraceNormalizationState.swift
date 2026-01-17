import CoreGraphics
import Foundation

struct TraceNormalizationState {
    var pointsByID: [UUID: CGPoint]
    let pointsByObject: [UUID: any ConnectionPoint]
    var links: [TraceSegment]
    var removedPointIDs: Set<UUID>
    var removedLinkIDs: Set<UUID>
    let epsilon: CGFloat
    let preferredIDs: Set<UUID>
}
