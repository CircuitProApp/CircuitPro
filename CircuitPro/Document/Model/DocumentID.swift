//
//  DocumentID.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import Foundation

struct DocumentID: Hashable, Codable, Sendable {
    let rawValue: UUID
    init(_ raw: UUID = UUID()) { self.rawValue = raw }
}


