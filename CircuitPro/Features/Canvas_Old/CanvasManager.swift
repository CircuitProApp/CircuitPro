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

    var magnification: CGFloat = 1



    var paperSize: PaperSize = .iso(.a4)

    var mouseLocation: CGPoint = .zero
    
    var mouseLocationInMM: CGPoint {
        mouseLocation / 10
    }

    var enableSnapping: Bool = true
    var showGuides: Bool = false

    var crosshairsStyle: CrosshairsStyle = .centeredCross
    var backgroundStyle: CanvasBackgroundStyle = .dotted

}
