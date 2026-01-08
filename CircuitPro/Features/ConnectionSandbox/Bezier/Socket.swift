import CoreGraphics
import Foundation

struct Socket: CanvasItem, ConnectionPoint, Hashable {
    let id: UUID
    var position: CGPoint
    var ownerID: UUID?

    init(id: UUID = UUID(), position: CGPoint, ownerID: UUID? = nil) {
        self.id = id
        self.position = position
        self.ownerID = ownerID
    }
}
