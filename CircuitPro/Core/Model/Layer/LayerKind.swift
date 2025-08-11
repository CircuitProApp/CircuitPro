//
//  LayerKind.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/18/25.
//

import SwiftUI

enum LayerKind: String, Displayable {
    case copper
    case silkscreen
    case solderMask
    case paste
    case adhesive
    case courtyard
    case fabrication
    case boardOutline
    case innerCopper // Used for inner layers (with LayerSide.inner)

    var label: String {
        switch self {
        case .copper:
            return "Copper"
        case .silkscreen:
            return "Silkscreen"
        case .solderMask:
            return "Solder Mask"
        case .paste:
            return "Paste"
        case .adhesive:
            return "Adhesive"
        case .courtyard:
            return "Courtyard"
        case .fabrication:
            return "Fabrication"
        case .boardOutline:
            return "Board Outline"
        case .innerCopper:
            return "Inner Copper"
        }
    }
}

extension LayerKind {
    var defaultColor: Color {
        switch self {
        case .copper: return .red
        case .silkscreen: return .gray.mix(with: .white, by: 0.5)
        case .solderMask: return .green.mix(with: .black, by: 0.1)
        case .paste: return .gray.mix(with: .black, by: 0.1)
        case .adhesive: return .orange
        case .courtyard: return .purple.mix(with: .white, by: 0.1)
        case .fabrication: return .blue
        case .boardOutline: return .gray
        case .innerCopper: return .cyan
        }
    }
}

extension LayerKind {
    /// Default z-index used when converting to ``CanvasLayer``.
    var zIndex: Int {
        switch self {
        case .boardOutline: return 0
        case .copper, .innerCopper: return 1
        case .solderMask: return 2
        case .paste: return 3
        case .silkscreen: return 4
        case .adhesive: return 5
        case .courtyard: return 6
        case .fabrication: return 7
        }
    }
}

extension LayerKind {
    /// Layer kinds that are used in footprint creation
    static var footprintLayers: [LayerKind] {
        return [
            .copper,
            .silkscreen,
            .solderMask,
            .paste,
            .courtyard,
            .fabrication
        ]
    }
}

extension LayerKind {
    /// A stable, hardcoded identifier for each layer kind to ensure consistency across sessions and for data serialization.
    /// NOTE: Do NOT change these values. They form a permanent contract for the footprint file format.
    var stableId: UUID {
        switch self {
        case .copper:       return UUID(uuidString: "B8A1B5E6-C3E8-4A7C-B8F0-9F0A2A3A5F9B")!
        case .silkscreen:   return UUID(uuidString: "C6C6E6A7-8A6A-4B6A-8E1A-9F0A2A3A5F9B")!
        case .solderMask:   return UUID(uuidString: "A5A5D5A4-7A5A-4A5A-7D0A-8F9A1A2A4F8A")!
        case .paste:        return UUID(uuidString: "D4D4F4B3-6A4A-494A-6C9A-7F8A0A1A3F7A")!
        case .adhesive:     return UUID(uuidString: "E3E3F3C2-5A3A-483A-5B8A-6F7A9A0A2F6A")!
        case .courtyard:    return UUID(uuidString: "F2F2E2D1-4A2A-472A-4A7A-5F6A8A9A1F5A")!
        case .fabrication:  return UUID(uuidString: "0101D1E0-3A1A-461A-396A-4F5A7A8A0F4A")!
        case .boardOutline: return UUID(uuidString: "1212A2F9-2A0A-450A-285A-3F4A6A7A9F3A")!
        case .innerCopper:  return UUID(uuidString: "2323B3A8-1A9A-449A-174A-2F3A5A6A8F2A")!
        }
    }
}
