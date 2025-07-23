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

    var magnification: CGFloat = 1
    var gridSpacing: GridSpacing = .mm1
    var scrollOrigin: CGPoint = .zero

    var paperSize: PaperSize = .iso(.a0)

    var mouseLocation: CGPoint = .zero
    
    var mouseLocationInMM: CGPoint {
        mouseLocation / 10
    }

    var enableSnapping: Bool = true
    var enableAxesBackground: Bool = true

    var crosshairsStyle: CrosshairsStyle = .centeredCross
    var backgroundStyle: CanvasBackgroundStyle = .dotted

    var showComponentDrawer: Bool = false

    func snap(_ point: CGPoint) -> CGPoint {
        guard enableSnapping else { return point }

        let gridSize = gridSpacing.rawValue * 10.0 // Matches the canvas

        func snapToGrid(_ value: CGFloat) -> CGFloat {
            round(value / gridSize) * gridSize
        }

        return CGPoint(
            x: snapToGrid(point.x),
            y: snapToGrid(point.y)
        )
    }
}

func normalize(_ value: CGFloat) -> CGFloat {
    return value == -0.0 ? 0.0 : value
}
