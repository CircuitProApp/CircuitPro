//
//  StageValidationError.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import Foundation

struct StageValidationError {
    let message: String
    let requirement: (any StageRequirement)?
}