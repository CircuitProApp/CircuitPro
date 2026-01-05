//
//  TextDisplayOptions.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/26/25.
//

import Foundation

/// Defines how a dynamic property source should be formatted into a final string.
struct TextDisplayOptions: Codable, Hashable {
    var showKey: Bool
    var showValue: Bool
    var showUnit: Bool

    /// A default configuration where all parts are visible.
    static var `default`: TextDisplayOptions {
        TextDisplayOptions(showKey: false, showValue: true, showUnit: true)
    }
}

enum TextDisplayPart {
    case key, value, unit
}
