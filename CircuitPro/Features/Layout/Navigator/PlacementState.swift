//
//  PlacementState.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import Foundation

/// Represents the placement status and location of a footprint on the PCB.
enum PlacementState: Hashable, Codable {
    case unplaced
    case placed(side: BoardSide)

    // --- We need a custom Codable implementation to handle the associated value ---

    private enum CodingKeys: String, CodingKey {
        case state
        case side
    }
    
    // When decoding, check the state and decode the associated value if it exists.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(String.self, forKey: .state)
        
        switch state {
        case "unplaced":
            self = .unplaced
        case "placed":
            let side = try container.decode(BoardSide.self, forKey: .side)
            self = .placed(side: side)
        default:
            throw DecodingError.dataCorruptedError(forKey: .state, in: container, debugDescription: "Invalid PlacementState value")
        }
    }

    // When encoding, write the state name and the associated value if it exists.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unplaced:
            try container.encode("unplaced", forKey: .state)
        case .placed(let side):
            try container.encode("placed", forKey: .state)
            try container.encode(side, forKey: .side)
        }
    }
}
