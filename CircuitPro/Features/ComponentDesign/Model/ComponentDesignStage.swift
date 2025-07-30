//
//  ComponentDesignStage.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/19/25.
//
import SwiftUI

protocol StageRequirement: Hashable { }

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

    // MARK: - Validation
    func validate(manager: ComponentDesignManager) -> (errors: [StageValidationError], warnings: [StageValidationError]) {
        var errors: [StageValidationError] = []
        var warnings: [StageValidationError] = []

        switch self {
        case .details:
            if manager.componentName.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Component name is required.", requirement: ComponentRequirement.name))
            }
            if manager.referenceDesignatorPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Reference designator prefix is required.", requirement: ComponentRequirement.referenceDesignatorPrefix))
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
            if manager.footprintElements.compactMap({ $0.primitive }).isEmpty {
                errors.append(.init(message: "No footprint created.", requirement: SymbolRequirement.primitives))
            }
            if manager.pads.isEmpty {
                errors.append(.init(message: "No pads added to footprint.", requirement: FootprintRequirement.pads))
            }
            for pad in manager.pads {
                if let drillDiameter = pad.drillDiameter {
                    let isTooLarge: Bool
                    switch pad.shape {
                    case .circle(let radius):
                        isTooLarge = drillDiameter > radius
                    case .rect(let width, let height):
                        isTooLarge = drillDiameter > width || drillDiameter > height
                    }
                    if isTooLarge {
                        warnings.append(.init(message: "Drill diameter for pad \(pad.number) exceeds its size.", requirement: FootprintRequirement.padDrillSize))
                    }
                }
            }
        }
        return (errors, warnings)
    }
}
