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
    var icon: String? { get }
    var helpText: String? { get }
}

extension Displayable {
    var id: Self { self }

    // Provide default nil implementations
    var icon: String? { nil }
    var helpText: String? { nil }
}
