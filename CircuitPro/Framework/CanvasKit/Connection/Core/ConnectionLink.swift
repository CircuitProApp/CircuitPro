//
//  ConnectionLink.swift
//  CircuitPro
//
//  Created by Codex on 1/2/26.
//

import Foundation

/// A logical connection linking two points by ID.
protocol ConnectionLink: Identifiable where ID == UUID {
    var startID: UUID { get }
    var endID: UUID { get }
}
