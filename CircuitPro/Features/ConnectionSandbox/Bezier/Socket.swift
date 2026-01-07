import CoreGraphics
import Foundation

struct Socket: CanvasItem, ConnectionPoint, Hashable {
    let id: UUID
    var position: CGPoint
    var connectedIDs: Set<UUID>
    var ownerID: UUID?

    init(id: UUID = UUID(), position: CGPoint, connectedIDs: Set<UUID> = [], ownerID: UUID? = nil) {
        self.id = id
        self.position = position
        self.connectedIDs = connectedIDs
        self.ownerID = ownerID
    }
}
