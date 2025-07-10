//
//  ComponentDesignStage.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//
import SwiftUI

protocol StageRequirement: Hashable { }

enum ComponentDesignStage: String, Displayable, CaseIterable {
    case component
    case symbol
    case footprint

    var label: String {
        switch self {
        case .component: return "Component Details"
        case .symbol: return "Symbol Creation"
        case .footprint: return "Footprint Creation"
        }
    }

    // MARK: - Stage-Specific Requirements
    enum ComponentRequirement: StageRequirement {
        case name, abbreviation, category, properties
    }
    enum SymbolRequirement: StageRequirement {
        case primitives, pins
    }
    enum FootprintRequirement: StageRequirement {
        case pads // Example
    }

    // MARK: - Validation
    func validate(manager: ComponentDesignManager) -> (errors: [StageValidationError], warnings: [StageValidationError]) {
        var errors: [StageValidationError] = []
        let warnings: [StageValidationError] = []

        switch self {
        case .component:
            if manager.componentName.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Component name is required.", requirement: ComponentRequirement.name))
            }
            if manager.componentAbbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Abbreviation is required.", requirement: ComponentRequirement.abbreviation))
            }
            if manager.selectedCategory == nil {
                errors.append(.init(message: "Choose a category.", requirement: ComponentRequirement.category))
            }
            if !manager.componentProperties.contains(where: { $0.key != nil }) {
                errors.append(.init(message: "At least one property should have a key.", requirement: ComponentRequirement.properties))
            }
        case .symbol:
            if manager.symbolElements.compactMap({ $0.primitive }).isEmpty {
                errors.append(.init(message: "No symbol created.", requirement: SymbolRequirement.primitives))
            }
            if manager.pins.isEmpty {
                errors.append(.init(message: "No pins added to symbol.", requirement: SymbolRequirement.pins))
            }
        case .footprint:
            // TODO: Add footprint validation logic
            break
        }
        return (errors, warnings)
    }
}