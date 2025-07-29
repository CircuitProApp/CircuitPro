//
//  AnchoredTextOverride.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//


import SwiftUI

struct AnchoredTextOverride: Identifiable, Codable, Hashable {
    let definitionID: UUID
    var textOverride: String?
    var relativePositionOverride: CGPoint?
    var isVisible: Bool = true
    var id: UUID { definitionID }
}