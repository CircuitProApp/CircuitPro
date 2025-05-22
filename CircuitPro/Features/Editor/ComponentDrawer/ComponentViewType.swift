//
//  ComponentViewType.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/16/25.
//
import SwiftUI

enum ComponentViewType: CaseIterable {
        case symbol
        case footprint

        var label: String {
            switch self {
            case .symbol: return "Symbol"
            case .footprint: return "Footprint"
            }
        }

        var icon: String {
            switch self {
            case .symbol: return AppIcons.symbol
            case .footprint: return AppIcons.footprint
            }
        }

        func isAvailable(in component: Component) -> Bool {
            switch self {
            case .symbol:
                return component.symbol != nil
            case .footprint:
                return component.footprints.isNotEmpty
            }
        }
    }
