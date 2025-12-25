//
//  ComponentValidator.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/1/25.
//

import Foundation

@MainActor
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
            if manager.componentProperties.isEmpty {
                errors.append(.init(message: "At least one property must be defined.", requirement: ComponentDesignStage.ComponentRequirement.properties))
            }
        case .symbol:
            let symbolPrimitives = manager.symbolEditor.canvasNodes.compactMap { ($0 as? PrimitiveNode)?.primitive }
            if symbolPrimitives.isEmpty {
                errors.append(.init(message: "No symbol created. The symbol must contain at least one shape.", requirement: ComponentDesignStage.SymbolRequirement.primitives))
            }
            if manager.symbolEditor.pins.isEmpty {
                errors.append(.init(message: "No pins added to symbol. The symbol must have at least one pin.", requirement: ComponentDesignStage.SymbolRequirement.pins))
            }
        case .footprint:
            // CORRECTED: Check the new `footprintDrafts` array.
            if manager.footprintDrafts.isEmpty && manager.assignedFootprints.isEmpty {
                errors.append(.init(message: "At least one footprint must be created or assigned.", requirement: ComponentDesignStage.FootprintRequirement.pads))
            }

            // CORRECTED: Iterate over the `footprintDrafts` array.
            for draft in manager.footprintDrafts {
                // The editor is now directly and safely accessible on the draft object.
                let editor = draft.editor

                let footprintPrimitives = editor.canvasNodes.compactMap { ($0 as? PrimitiveNode)?.primitive }
                if footprintPrimitives.isEmpty {
                    // Use the draft's name for the error message.
                    errors.append(.init(message: "Footprint '\(draft.name)' must contain at least one shape.", requirement: ComponentDesignStage.SymbolRequirement.primitives))
                }
                if editor.pads.isEmpty {
                    errors.append(.init(message: "Footprint '\(draft.name)' must have at least one pad.", requirement: ComponentDesignStage.FootprintRequirement.pads))
                }
                for pad in editor.pads {
                    if let drillDiameter = pad.drillDiameter {
                        let isTooLarge: Bool
                        switch pad.shape {
                        case .circle(let radius):
                            isTooLarge = drillDiameter >= (radius * 2)
                        case .rect(let width, let height):
                            isTooLarge = drillDiameter >= min(width, height)
                        }
                        if isTooLarge {
                            warnings.append(.init(message: "Drill diameter for pad \(pad.number) in footprint '\(draft.name)' is larger than or equal to the pad size.", requirement: ComponentDesignStage.FootprintRequirement.padDrillSize))
                        }
                    }
                }
            }
        }
        return (errors, warnings)
    }
}
