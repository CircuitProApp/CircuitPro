//
//  GraphPinID.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

enum GraphPinID {
    static func makeID(ownerID: UUID?, pinID: UUID) -> UUID {
        guard let ownerID else { return pinID }
        return stableID(for: ownerID, pinID: pinID)
    }

    static func stableID(for ownerID: UUID, pinID: UUID) -> UUID {
        var ownerBytes = ownerID.uuid
        var pinBytes = pinID.uuid
        var resultBytes = ownerBytes

        withUnsafeMutableBytes(of: &resultBytes) { resultPtr in
            withUnsafeBytes(of: &pinBytes) { pinPtr in
                for i in 0..<resultPtr.count {
                    resultPtr[i] ^= pinPtr[i]
                }
            }
        }
        return UUID(uuid: resultBytes)
    }
}
