import Foundation

struct BezierLink: CanvasItem, ConnectionLink, Hashable {
    let id: UUID
    var startID: UUID
    var endID: UUID

    init(id: UUID = UUID(), startID: UUID, endID: UUID) {
        self.id = id
        self.startID = startID
        self.endID = endID
    }
}
