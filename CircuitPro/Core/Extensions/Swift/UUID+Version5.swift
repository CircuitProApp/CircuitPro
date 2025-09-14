//
//  UUID+Version5.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import Foundation
import CryptoKit

extension UUID {
    /// Creates a deterministic, version 5 UUID from a string and a namespace UUID.
    ///
    /// The same name and namespace will always produce the same UUID.
    /// - Parameters:
    ///   - name: The string to be hashed into the UUID.
    ///   - namespace: The UUID namespace.
    init(name: String, namespace: UUID) {
        // 1. Get the raw bytes of the namespace.
        var namespaceBytes = namespace.uuid
        let namespaceData = withUnsafeBytes(of: &namespaceBytes) { Data($0) }
        
        // 2. Get the UTF-8 bytes of the name.
        guard let nameData = name.data(using: .utf8) else {
            fatalError("Could not convert name to UTF-8 data.")
        }
        
        // 3. Combine the namespace and name data.
        var combinedData = Data()
        combinedData.append(namespaceData)
        combinedData.append(nameData)
        
        // 4. Compute the SHA-1 hash of the combined data.
        var digest = Insecure.SHA1.hash(data: combinedData)
        
        // 5. Extract the first 16 bytes of the hash to form the UUID.
        let uuidBytes: uuid_t = withUnsafeBytes(of: &digest) {
            var bytes: uuid_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            let bufferPointer = UnsafeMutableRawBufferPointer(start: &bytes, count: 16)
            bufferPointer.copyMemory(from: UnsafeRawBufferPointer($0))
            return bytes
        }
        
        var rawUUID = uuidBytes
        
        // 6. Set the version bits to 5 (0101).
        // digest[6] is the 7th byte (0-indexed).
        // Clear the 4 most significant bits and set them to 0101.
        withUnsafeMutableBytes(of: &rawUUID) { pointer in
            pointer[6] = (pointer[6] & 0x0F) | 0x50
        }
        
        // 7. Set the variant bits to RFC 4122 (10xx).
        // digest[8] is the 9th byte.
        // Clear the 2 most significant bits and set them to 10.
        withUnsafeMutableBytes(of: &rawUUID) { pointer in
            pointer[8] = (pointer[8] & 0x3F) | 0x80
        }

        // 8. Initialize the UUID with the modified bytes.
        self.init(uuid: rawUUID)
    }
}
