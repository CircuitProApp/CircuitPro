//
//  ValidationSummary.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

struct ValidationSummary {
    var errors:   [ComponentField : String] = [:]
    var warnings: [ComponentField : String] = [:]
    var isValid:  Bool { errors.isEmpty }
}


