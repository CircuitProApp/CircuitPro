import CoreGraphics
import Foundation

/// A lightweight trace point that can participate in CanvasKit interactions.
struct TraceVertex: CanvasItem, ConnectionPoint, Hashable, Codable {
    static let legacyUnassignedLayerID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    let id: UUID
    var position: CGPoint
    var layerId: UUID

    init(id: UUID = UUID(), position: CGPoint, layerId: UUID) {
        self.id = id
        self.position = position
        self.layerId = layerId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case layerId
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.layerId =
            try container.decodeIfPresent(UUID.self, forKey: .layerId)
            ?? Self.legacyUnassignedLayerID
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encode(layerId, forKey: .layerId)
    }
}
