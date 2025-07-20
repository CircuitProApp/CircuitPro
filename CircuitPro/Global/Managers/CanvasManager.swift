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

    var showDrawingSheet: Bool = true
    var paperSize: PaperSize = .iso(.a5)

    var mouseLocation: CGPoint = CGPoint(x: 2500, y: 2500)

    var enableSnapping: Bool = true
    var enableAxesBackground: Bool = true

    var crosshairsStyle: CrosshairsStyle = .centeredCross
    var backgroundStyle: CanvasBackgroundStyle = .dotted

    var showComponentDrawer: Bool = false

    var relativeMousePosition: CGPoint {
        CGPoint(
            x: mouseLocation.x - 2500,
            y: normalize(-(mouseLocation.y - 2500))
        )
    }

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
