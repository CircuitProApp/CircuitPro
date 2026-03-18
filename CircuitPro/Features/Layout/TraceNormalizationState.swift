import CoreGraphics
import Foundation

struct TraceNormalizationState {
    var pointsByID: [UUID: CGPoint]
    var pointsByObject: [UUID: any ConnectionPoint]
    var traceVerticesByID: [UUID: TraceVertex]
    var links: [TraceSegment]
    var addedPoints: [TraceVertex]
    var removedPointIDs: Set<UUID>
    var removedLinkIDs: Set<UUID>
    let epsilon: CGFloat
    let preferredIDs: Set<UUID>
}
