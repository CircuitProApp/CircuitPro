//
//  CanvasManager.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/3/25.
//

import SwiftUI
import Observation

@Observable
final class CanvasManager {

    var environment = CanvasEnvironmentValues()

    var viewport = CanvasViewport.centered(documentSize: PaperSize.iso(.a4).canvasSize())

    var mouseLocation: CGPoint = .zero

    var mouseLocationInMM: CGPoint {
        mouseLocation / CircuitPro.Constants.pointsPerMillimeter
    }

    func applyTheme(_ theme: CanvasTheme) {
        environment.canvasTheme = theme
    }

    func applySchematicTheme(_ theme: SchematicTheme) {
        environment.schematicTheme = theme
    }
}
