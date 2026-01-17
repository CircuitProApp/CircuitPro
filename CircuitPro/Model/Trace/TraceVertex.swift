import CoreGraphics
import Foundation

/// A lightweight trace point that can participate in CanvasKit interactions.
struct TraceVertex: CanvasItem, ConnectionPoint, Hashable, Codable {
    let id: UUID
    var position: CGPoint

    init(id: UUID = UUID(), position: CGPoint) {
        self.id = id
        self.position = position
    }
}
