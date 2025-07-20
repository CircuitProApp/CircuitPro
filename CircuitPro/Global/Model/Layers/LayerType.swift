//
//  LayerType 2.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI

enum LayerType: String, Codable, CaseIterable {
    case frontCopper = "Front Copper"
    case backCopper = "Back Copper"

    case frontSolderMask = "Front Solder Mask"
    case backSolderMask = "Back Solder Mask"
    case frontSilkscreen = "Front Silkscreen"
    case backSilkscreen = "Back Silkscreen"
    case frontPaste = "Front Paste"
    case backPaste = "Back Paste"
    case frontAdhesive = "Front Adhesive"
    case backAdhesive = "Back Adhesive"
    case boardOutline = "Board Outline"
    case frontCourtyard = "Front Courtyard"
    case backCourtyard = "Back Courtyard"
    case frontFabrication = "Front Fabrication"
    case backFabrication = "Back Fabrication"

    // MARK: Inner Layers
    case innerCopper1 = "Inner Copper 1"
    case innerCopper2 = "Inner Copper 2"
}

extension LayerType {
    var defaultColor: Color {
        switch self {
        case .frontCopper: return .red
        case .backCopper: return .blue
        case .boardOutline: return .gray
        default: return .gray
        }
    }
}

extension LayerType {
    // Define the default (non-inner) layers
    static var defaultLayerTypes: [LayerType] {
        return [
            .frontCopper,
            .backCopper,
            .frontSolderMask,
            .backSolderMask,
            .frontSilkscreen,
            .backSilkscreen,
            .frontPaste,
            .backPaste,
            .frontAdhesive,
            .backAdhesive,
            .boardOutline,
            .frontCourtyard,
            .backCourtyard,
            .frontFabrication,
            .backFabrication
        ]
    }
}

extension LayerType {
    static var usedInFootprints: [LayerType] {
        return [
            .frontCopper, .backCopper,
            .frontPaste, .backPaste,
            .frontSolderMask, .backSolderMask,
            .frontSilkscreen, .backSilkscreen,
            .boardOutline,
            .frontCourtyard, .backCourtyard,
            .frontFabrication, .backFabrication
        ]
    }
}
