//
//  ComponentDesignStage.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//
import SwiftUI

protocol StageRequirement: Hashable {}

enum FootprintStageMode: Displayable {
    case create
    case select
    
    var label: String {
        switch self {
        case .create:
            "Create"
        case .select:
            "Select"
        }
    }
}

enum ComponentDesignStage: String, Displayable, CaseIterable {
    case details
    case symbol
    case footprint

    var label: String {
        switch self {
        case .details: return "Details"
        case .symbol: return "Symbol"
        case .footprint: return "Footprint"
        }
    }

    // MARK: - Stage-Specific Requirements
    enum ComponentRequirement: StageRequirement {
        case name, referenceDesignatorPrefix, category, properties
    }
    enum SymbolRequirement: StageRequirement {
        case primitives, pins
    }
    enum FootprintRequirement: StageRequirement {
        case pads, padDrillSize
    }
}
