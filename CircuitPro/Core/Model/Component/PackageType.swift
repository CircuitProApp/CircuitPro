//
//  PackageType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//
import SwiftUI

enum PackageType: String, Displayable {

    case qfn
    case tqfp
    case soic
    case sot23
    case dfn
    case lga
    case dip
    case sip
    case bga
    case to220
    case _0402
    case _0603
    case _0805
    case _1206
    case module
    case devBoard
    case systemOnModule

    var label: String {
        switch self {
        case .qfn: return "QFN"
        case .tqfp: return "TQFP"
        case .soic: return "SOIC"
        case .sot23: return "SOT-23"
        case .dfn: return "DFN"
        case .lga: return "LGA"
        case .dip: return "DIP"
        case .sip: return "SIP"
        case .bga: return "BGA"
        case .to220: return "TO-220"
        case ._0402: return "0402"
        case ._0603: return "0603"
        case ._0805: return "0805"
        case ._1206: return "1206"
        case .module: return "Module"
        case .devBoard: return "Development Board"
        case .systemOnModule: return "System-on-Module"
        }
    }
}
