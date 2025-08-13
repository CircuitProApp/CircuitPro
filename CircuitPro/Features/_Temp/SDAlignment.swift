//
//  SDAlignment.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

enum SDAlignment: String, Codable, Hashable {
    case left
    case center
    case right
    case justified
    case natural

    init(alignment: NSTextAlignment) {
        switch alignment {
        case .left: self = .left
        case .center: self = .center
        case .right: self = .right
        case .justified: self = .justified
        case .natural: self = .natural
        @unknown default: self = .natural
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        case .natural: return .natural
        }
    }
}
