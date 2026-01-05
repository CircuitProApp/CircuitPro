//
//  LayerType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI
import Foundation

/// Represents a specific, physical layer in a board design's stackup.
/// It combines an abstract `LayerKind` with a physical `LayerSide`.
struct LayerType: Hashable, Codable, Identifiable {
    let id: UUID
    var name: String
    let kind: LayerKind
    let side: LayerSide?

    var layerKind: LayerKind {
        kind
    }
}

// MARK: - Default Colors
extension LayerType {
    var defaultColor: Color {
        switch (kind, side) {
        case (.copper, .back):
            return .blue
        case (.innerCopper, _):
            return .cyan
        default:
            return kind.defaultColor
        }
    }
}

extension LayerType {
    /// Determines if a layer is a copper layer that can have traces.
    var isTraceable: Bool {
        switch self.kind {
        case .copper, .innerCopper:
            return true
        default:
            return false
        }
    }
}

// MARK: - Standard Layer Definitions
extension LayerType {
    static let frontCopper      = LayerType(id: UUID(uuidString: "F9B6E1A3-C6D4-4A8E-9B1A-0E1F2A3B4C5D")!, name: "Front Copper", kind: .copper, side: .front)
    static let backCopper       = LayerType(id: UUID(uuidString: "B8A5D0B2-B5C3-497D-8A0B-1F2A3B4C5D6E")!, name: "Back Copper", kind: .copper, side: .back)

    static let frontSolderMask  = LayerType(id: UUID(uuidString: "A794C9C1-A4B2-486C-79FB-2A3B4C5D6E7F")!, name: "Front Solder Mask", kind: .solderMask, side: .front)
    static let backSolderMask   = LayerType(id: UUID(uuidString: "9683B8D0-93A1-475B-68EA-3B4C5D6E7F80")!, name: "Back Solder Mask", kind: .solderMask, side: .back)

    static let frontSilkscreen  = LayerType(id: UUID(uuidString: "8572A7E9-8290-464A-57D9-4C5D6E7F8091")!, name: "Front Silkscreen", kind: .silkscreen, side: .front)
    static let backSilkscreen   = LayerType(id: UUID(uuidString: "746196F8-718F-4539-46C8-5D6E7F8091A2")!, name: "Back Silkscreen", kind: .silkscreen, side: .back)

    static let frontPaste       = LayerType(id: UUID(uuidString: "635085A7-607E-4428-35B7-6E7F8091A2B3")!, name: "Front Paste", kind: .paste, side: .front)
    static let backPaste        = LayerType(id: UUID(uuidString: "524F74B6-5F6D-4317-24A6-7F8091A2B3C4")!, name: "Back Paste", kind: .paste, side: .back)

    static let frontAdhesive    = LayerType(id: UUID(uuidString: "413E63C5-4E5C-4206-1395-8091A2B3C4D5")!, name: "Front Adhesive", kind: .adhesive, side: .front)
    static let backAdhesive     = LayerType(id: UUID(uuidString: "302D52D4-3D4B-41F5-0284-91A2B3C4D5E6")!, name: "Back Adhesive", kind: .adhesive, side: .back)

    static let frontCourtyard   = LayerType(id: UUID(uuidString: "2F1C41E3-2C3A-40E4-F173-A2B3C4D5E6F7")!, name: "Front Courtyard", kind: .courtyard, side: .front)
    static let backCourtyard    = LayerType(id: UUID(uuidString: "1E0B30F2-1B29-4FD3-E062-B3C4D5E6F708")!, name: "Back Courtyard", kind: .courtyard, side: .back)

    static let frontFabrication = LayerType(id: UUID(uuidString: "0DFA2FF1-0A18-4EC2-DF51-C4D5E6F70819")!, name: "Front Fabrication", kind: .fabrication, side: .front)
    static let backFabrication  = LayerType(id: UUID(uuidString: "FCDE1EE0-FA07-4DB1-CE40-D5E6F708192A")!, name: "Back Fabrication", kind: .fabrication, side: .back)

    static let boardOutline     = LayerType(id: UUID(uuidString: "EBBD0DD9-E9F6-4CA0-BD3F-E6F708192A3B")!, name: "Board Outline", kind: .boardOutline, side: nil)

    private static let innerCopperNamespace = UUID(uuidString: "C9ACFFD8-E8E5-4B9F-BC2E-F708192A3B4C")!

    static func innerCopper(index: Int) -> LayerType {
        precondition(index > 0, "Inner layer index must be positive.")
        
        // This initializer now exists and works correctly.
        let stableID = UUID(name: "inner_copper_\(index)", namespace: innerCopperNamespace)
        
        return LayerType(
            id: stableID,
            name: "Inner Copper \(index)",
            kind: .innerCopper,
            side: .inner(index)
        )
    }
}

// MARK: - Default Stackups
extension LayerType {
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
