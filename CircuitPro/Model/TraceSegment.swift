import Foundation
import CoreGraphics

struct TraceSegment: Codable, Hashable {
    var start: CGPoint
    var end: CGPoint
    var width: CGFloat
    var layerId: UUID

    func normalized() -> TraceSegment {
        if start.x < end.x || (start.x == end.x && start.y <= end.y) {
            return self
        }
        return TraceSegment(start: end, end: start, width: width, layerId: layerId)
    }

    var sortKey: (String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        (layerId.uuidString, width, start.x, start.y, end.x, end.y)
    }
}
