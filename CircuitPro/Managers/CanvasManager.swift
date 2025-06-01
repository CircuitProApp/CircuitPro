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
}

func normalize(_ value: CGFloat) -> CGFloat {
    return value == -0.0 ? 0.0 : value
}
