import Foundation

struct CanvasStyle: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var backgroundHex: String
    var gridHex: String
    var textHex: String
    var markerHex: String
    var crosshairHex: String
    var isBuiltin: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundHex
        case gridHex
        case textHex
        case markerHex
        case crosshairHex
        case isBuiltin
    }

    init(
        id: UUID,
        name: String,
        backgroundHex: String,
        gridHex: String,
        textHex: String,
        markerHex: String,
        crosshairHex: String,
        isBuiltin: Bool
    ) {
        self.id = id
        self.name = name
        self.backgroundHex = backgroundHex
        self.gridHex = gridHex
        self.textHex = textHex
        self.markerHex = markerHex
        self.crosshairHex = crosshairHex
        self.isBuiltin = isBuiltin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        backgroundHex = try container.decode(String.self, forKey: .backgroundHex)
        gridHex = try container.decode(String.self, forKey: .gridHex)
        textHex = try container.decode(String.self, forKey: .textHex)
        markerHex = try container.decode(String.self, forKey: .markerHex)
        crosshairHex =
            try container.decodeIfPresent(String.self, forKey: .crosshairHex) ?? "#3B82F6"
        isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
    }
}
