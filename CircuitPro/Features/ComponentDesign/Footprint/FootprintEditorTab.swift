//
//  FootprintEditorTab.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import Foundation

/// Defines the tabs available in the footprint editor sidebar.
enum FootprintEditorTab: String, CaseIterable, Identifiable {
    case pads = "Pads"
    case geometry = "Geometry"
    var id: Self { self }
}
