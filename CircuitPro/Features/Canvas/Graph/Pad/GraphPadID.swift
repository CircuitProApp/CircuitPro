//
//  GraphPadID.swift
//  CircuitPro
//
//  Created by Codex on 9/22/25.
//

import Foundation

enum GraphPadID {
    static func makeID(ownerID: UUID?, padID: UUID) -> UUID {
        guard let ownerID else { return padID }
        return stableID(for: ownerID, padID: padID)
    }

    static func stableID(for ownerID: UUID, padID: UUID) -> UUID {
        var ownerBytes = ownerID.uuid
        var padBytes = padID.uuid
        var resultBytes = ownerBytes

        withUnsafeMutableBytes(of: &resultBytes) { resultPtr in
            withUnsafeBytes(of: &padBytes) { padPtr in
                for i in 0..<resultPtr.count {
                    resultPtr[i] ^= padPtr[i]
                }
            }
        }
        return UUID(uuid: resultBytes)
    }
}
