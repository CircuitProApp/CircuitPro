//
//  LayerType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI

/// Represents a specific, physical layer in a board design's stackup.
/// It combines an abstract `LayerKind` with a physical `LayerSide`.
struct LayerType: Hashable, Codable, Identifiable {
    let id: String
    var name: String
    let kind: LayerKind
    // Side is optional to accommodate layers like .boardOutline that don't have a side.
    let side: LayerSide?

    /// The abstract category of this layer.
    var layerKind: LayerKind {
        kind
    }
}

/// Represents the total number of copper layers in a manufacturable PCB.
enum BoardLayerCount: Int, CaseIterable, Codable, Identifiable {
    case two = 2
    case four = 4
    case six = 6
    case eight = 8
    case ten = 10
    case twelve = 12
    case fourteen = 14
    case sixteen = 16

    var id: Int { self.rawValue }

    /// The number of inner copper layers for this board type.
    var innerLayerCount: Int {
        guard self.rawValue > 2 else { return 0 }
        return self.rawValue - 2
    }
}


// MARK: - Default Colors
extension LayerType {
    var defaultColor: Color {
        // Specific overrides for board-level display
        switch (kind, side) {
        case (.copper, .back):
            return .blue
        case (.innerCopper, _):
            return .cyan
        default:
            // Fallback to the generic color from the kind
            return kind.defaultColor
        }
    }
}

// MARK: - Standard Layer Definitions
extension LayerType {
    // Paired Layers
    static let frontCopper      = LayerType(id: "front_copper", name: "Front Copper", kind: .copper, side: .front)
    static let backCopper       = LayerType(id: "back_copper", name: "Back Copper", kind: .copper, side: .back)

    static let frontSolderMask  = LayerType(id: "front_solderMask", name: "Front Solder Mask", kind: .solderMask, side: .front)
    static let backSolderMask   = LayerType(id: "back_solderMask", name: "Back Solder Mask", kind: .solderMask, side: .back)

    static let frontSilkscreen  = LayerType(id: "front_silkscreen", name: "Front Silkscreen", kind: .silkscreen, side: .front)
    static let backSilkscreen   = LayerType(id: "back_silkscreen", name: "Back Silkscreen", kind: .silkscreen, side: .back)

    static let frontPaste       = LayerType(id: "front_paste", name: "Front Paste", kind: .paste, side: .front)
    static let backPaste        = LayerType(id: "back_paste", name: "Back Paste", kind: .paste, side: .back)

    static let frontAdhesive    = LayerType(id: "front_adhesive", name: "Front Adhesive", kind: .adhesive, side: .front)
    static let backAdhesive     = LayerType(id: "back_adhesive", name: "Back Adhesive", kind: .adhesive, side: .back)

    static let frontCourtyard   = LayerType(id: "front_courtyard", name: "Front Courtyard", kind: .courtyard, side: .front)
    static let backCourtyard    = LayerType(id: "back_courtyard", name: "Back Courtyard", kind: .courtyard, side: .back)

    static let frontFabrication = LayerType(id: "front_fabrication", name: "Front Fabrication", kind: .fabrication, side: .front)
    static let backFabrication  = LayerType(id: "back_fabrication", name: "Back Fabrication", kind: .fabrication, side: .back)

    // Singular Layers
    static let boardOutline     = LayerType(id: "board_outline", name: "Board Outline", kind: .boardOutline, side: nil)

    /// Factory function for creating dynamic inner copper layers.
    /// - Parameter index: The 1-based index of the inner layer.
    static func innerCopper(index: Int) -> LayerType {
        precondition(index > 0, "Inner layer index must be positive.")
        return LayerType(id: "inner_copper_\(index)", name: "Inner Copper \(index)", kind: .innerCopper, side: .inner(index))
    }
}

// MARK: - Default Stackups
extension LayerType {
    /// Generates a standard layer stackup for a new board design.
    /// - Parameter layerCount: The total number of copper layers for the board.
    static func defaultStackup(layerCount: BoardLayerCount = .two) -> [LayerType] {
        var layers: [LayerType] = [
            .frontCopper,
            .frontSolderMask,
            .frontSilkscreen,
            .frontPaste,
            .frontAdhesive,
            .frontCourtyard,
            .frontFabrication
        ]

        if layerCount.innerLayerCount > 0 {
            for i in 1...layerCount.innerLayerCount {
                layers.append(.innerCopper(index: i))
            }
        }

        layers.append(contentsOf: [
            .backCopper,
            .backSolderMask,
            .backSilkscreen,
            .backPaste,
            .backAdhesive,
            .backCourtyard,
            .backFabrication
        ])
        
        layers.append(.boardOutline)
        
        return layers
    }
}
