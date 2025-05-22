//
//  ComponentDesignStage.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//
import SwiftUI

 enum ComponentDesignStage: String, Displayable {
        case component
        case symbol
        case footprint

        var label: String {
            switch self {
            case .component:
                return "Component Details"
            case .symbol:
                return "Symbol Creation"
            case .footprint:
                return "Footprint Creation"
            }
        }
    }
