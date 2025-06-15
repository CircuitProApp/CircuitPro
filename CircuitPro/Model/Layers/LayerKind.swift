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
