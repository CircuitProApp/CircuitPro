//
//  RemotePack.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import Foundation

struct RemotePack: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let version: Int
    let description: String
    let downloadURL: URL
}
