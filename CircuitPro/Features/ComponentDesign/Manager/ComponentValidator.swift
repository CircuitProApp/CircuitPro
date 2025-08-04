//
//  ComponentValidator.swift
//  CircuitPro
//
//  Created by Gemini on 8/1/25.
//

import Foundation

struct ComponentValidator {
    
    private let manager: ComponentDesignManager
    
    init(manager: ComponentDesignManager) {
        self.manager = manager
    }
    
    func validate() -> ValidationSummary {
        var summary = ValidationSummary()

        for stage in ComponentDesignStage.allCases {
            let stageResult = validate(stage: stage)

            if !stageResult.errors.isEmpty {
                summary.errors[stage] = stageResult.errors
            }

            if !stageResult.warnings.isEmpty {
                summary.warnings[stage] = stageResult.warnings
            }
        }

        return summary
    }
    
    private func validate(stage: ComponentDesignStage) -> (errors: [StageValidationError], warnings: [StageValidationError]) {
        var errors: [StageValidationError] = []
        var warnings: [StageValidationError] = []

        switch stage {
        case .details:
            if manager.componentName.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Component name is required.", requirement: ComponentDesignStage.ComponentRequirement.name))
            }
            if manager.referenceDesignatorPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append(.init(message: "Reference designator prefix is required.", requirement: ComponentDesignStage.ComponentRequirement.referenceDesignatorPrefix))
            }
            if manager.selectedCategory == nil {
                errors.append(.init(message: "Choose a category.", requirement: ComponentDesignStage.ComponentRequirement.category))
            }
            if !manager.componentProperties.contains(where: { $0.key != nil }) {
                errors.append(.init(message: "At least one property should have a key.", requirement: ComponentDesignStage.ComponentRequirement.properties))
            }
        case .symbol:
            if manager.symbolEditor.elements.compactMap({ $0 as? AnyPrimitive }).isEmpty {
                errors.append(.init(message: "No symbol created.", requirement: ComponentDesignStage.SymbolRequirement.primitives))
            }
            if manager.symbolEditor.pins.isEmpty {
                errors.append(.init(message: "No pins added to symbol.", requirement: ComponentDesignStage.SymbolRequirement.pins))
            }
        case .footprint:
            if manager.footprintEditor.elements.compactMap({ $0 as? AnyPrimitive}).isEmpty {
                errors.append(.init(message: "No footprint created.", requirement: ComponentDesignStage.SymbolRequirement.primitives))
            }
            if manager.footprintEditor.pads.isEmpty {
                errors.append(.init(message: "No pads added to footprint.", requirement: ComponentDesignStage.FootprintRequirement.pads))
            }
            for pad in manager.footprintEditor.pads {
                if let drillDiameter = pad.drillDiameter {
                    let isTooLarge: Bool
                    switch pad.shape {
                    case .circle(let radius):
                        isTooLarge = drillDiameter > radius
                    case .rect(let width, let height):
                        isTooLarge = drillDiameter > width || drillDiameter > height
                    }
                    if isTooLarge {
                        warnings.append(.init(message: "Drill diameter for pad \(pad.number) exceeds its size.", requirement: ComponentDesignStage.FootprintRequirement.padDrillSize))
                    }
                }
            }
        }
        return (errors, warnings)
    }
}
