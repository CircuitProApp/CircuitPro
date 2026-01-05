//
//  EditorType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/4/25.
//

enum EditorType {
    case schematic, layout
}

extension EditorType {
    var changeSource: ChangeSource {
        switch self {
        case .schematic:
            return .schematic
        case .layout:
            return .layout
        }
    }
}

enum TextTarget { case symbol, footprint }

extension EditorType {
    var textTarget: TextTarget {
        switch self {
        case .schematic: return .symbol
        case .layout:    return .footprint
        }
    }
}
