//
//  ValidationSummary.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

struct ValidationSummary {
    var errors:   [ComponentDesignStage: [StageValidationError]] = [:]
    var warnings: [ComponentDesignStage: [StageValidationError]] = [:]

    var isValid: Bool {
        errors.isEmpty
    }

    var requirementErrors: [AnyHashable: String] {
        var dict: [AnyHashable: String] = [:]
        for stageErrors in errors.values {
            for error in stageErrors {
                if let req = error.requirement {
                    dict[AnyHashable(req)] = error.message
                }
            }
        }
        return dict
    }

    var requirementWarnings: [AnyHashable: String] {
        var dict: [AnyHashable: String] = [:]
        for stageWarnings in warnings.values {
            for warning in stageWarnings {
                if let req = warning.requirement {
                    dict[AnyHashable(req)] = warning.message
                }
            }
        }
        return dict
    }
}
