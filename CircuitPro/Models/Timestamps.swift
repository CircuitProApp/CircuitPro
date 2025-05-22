//
//  TimeStamps.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//
import SwiftUI

struct Timestamps: Codable, Sendable {
    var dateCreated: Date = Date()
    var dateModified: Date = Date()
    var dateDeleted: Date?
}
