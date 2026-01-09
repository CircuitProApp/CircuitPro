import Foundation

struct CanvasStyle: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var backgroundHex: String
    var gridHex: String
    var textHex: String
    var markerHex: String
    var crosshairHex: String
    var schematicSymbolHex: String
    var schematicPinHex: String
    var schematicTextHex: String
    var schematicWireHex: String
    var isBuiltin: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundHex
        case gridHex
        case textHex
        case markerHex
        case crosshairHex
        case schematicSymbolHex
        case schematicPinHex
        case schematicTextHex
        case schematicWireHex
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
        schematicSymbolHex: String,
        schematicPinHex: String,
        schematicTextHex: String,
        schematicWireHex: String,
        isBuiltin: Bool
    ) {
        self.id = id
        self.name = name
        self.backgroundHex = backgroundHex
        self.gridHex = gridHex
        self.textHex = textHex
        self.markerHex = markerHex
        self.crosshairHex = crosshairHex
        self.schematicSymbolHex = schematicSymbolHex
        self.schematicPinHex = schematicPinHex
        self.schematicTextHex = schematicTextHex
        self.schematicWireHex = schematicWireHex
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
        schematicSymbolHex =
            try container.decodeIfPresent(String.self, forKey: .schematicSymbolHex) ?? textHex
        schematicPinHex =
            try container.decodeIfPresent(String.self, forKey: .schematicPinHex) ?? crosshairHex
        schematicTextHex =
            try container.decodeIfPresent(String.self, forKey: .schematicTextHex) ?? textHex
        schematicWireHex =
            try container.decodeIfPresent(String.self, forKey: .schematicWireHex) ?? crosshairHex
        isBuiltin = try container.decode(Bool.self, forKey: .isBuiltin)
    }
}
