import CoreGraphics
import Foundation

struct TraceSegment: CanvasItem, ConnectionLink, Hashable, Codable {
    var id: UUID
    var startID: UUID
    var endID: UUID
    var width: CGFloat
    var layerId: UUID

    init(
        id: UUID = UUID(),
        startID: UUID,
        endID: UUID,
        width: CGFloat,
        layerId: UUID
    ) {
        self.id = id
        self.startID = startID
        self.endID = endID
        self.width = width
        self.layerId = layerId
    }
}
