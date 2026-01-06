//
//  ConnectionEdge.swift
//  CircuitPro
//
//  Created by Codex on 1/2/26.
//

import Foundation

/// A connection edge linking two anchors by ID.
protocol ConnectionEdge: Identifiable where ID == UUID {
    var startID: UUID { get }
    var endID: UUID { get }
}
