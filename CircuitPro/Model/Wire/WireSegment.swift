import Foundation

// Represents a single segment of a wire.
struct WireSegment: CanvasItem, ConnectionLink, Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var startID: UUID
    var endID: UUID

    // Compare by content, not by id
    static func == (lhs: WireSegment, rhs: WireSegment) -> Bool {
        lhs.startID == rhs.startID && lhs.endID == rhs.endID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(startID)
        hasher.combine(endID)
    }
}
