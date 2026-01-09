//
//  Displayable.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/11/25.
//

import SwiftUI

/// A clean Displayable protocol for enums used in UI
protocol Displayable: CaseIterable, Identifiable, Codable, Hashable {
    var label: String { get }
    var iconName: String { get }
    var iconColor: Color { get }
    var color: Color { get }
    var helpText: String { get }
}

extension Displayable {
    var id: Self { self }

    // Provide default non-optional implementations
    var iconName: String { "" }
    var iconColor: Color { .primary }
    var color: Color { .primary }
    var helpText: String { "" }
}
