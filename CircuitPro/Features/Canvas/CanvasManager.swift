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

    var runtime: CanvasRuntimeState
    var environment: CanvasEnvironmentValues

    var viewport = CanvasViewport.centered(documentSize: PaperSize.iso(.a4).canvasSize())

    init() {
        let runtime = CanvasRuntimeState()
        var environment = CanvasEnvironmentValues()
        environment.useRuntime(runtime)
        self.runtime = runtime
        self.environment = environment
    }

    var mouseLocation: CGPoint {
        runtime.processedMouseLocation ?? .zero
    }

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
