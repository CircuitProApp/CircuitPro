//
//  CanvasTextID.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

enum CanvasTextID {
    static func makeID(for source: CircuitText.Source, ownerID: UUID, fallback: UUID) -> UUID {
        switch source {
        case .definition(let definition):
            return stableID(for: ownerID, definitionID: definition.id)
        case .instance:
            return fallback
        }
    }

    static func stableID(for ownerID: UUID, definitionID: UUID) -> UUID {
        let ownerBytes = ownerID.uuid
        var definitionBytes = definitionID.uuid
        var resultBytes = ownerBytes

        withUnsafeMutableBytes(of: &resultBytes) { resultPtr in
            withUnsafeBytes(of: &definitionBytes) { definitionPtr in
                for i in 0..<resultPtr.count {
                    resultPtr[i] ^= definitionPtr[i]
                }
            }
        }
        return UUID(uuid: resultBytes)
    }
}
