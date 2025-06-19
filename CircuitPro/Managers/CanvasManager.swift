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
    
    var paperSize: PaperSize = .a5

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
        let grid = gridSpacing.rawValue * 10.0          // matches the canvas
        func snapValue(_ v: CGFloat) -> CGFloat { round(v / grid) * grid }
        return CGPoint(x: snapValue(point.x), y: snapValue(point.y))
    }
}

func normalize(_ value: CGFloat) -> CGFloat {
    return value == -0.0 ? 0.0 : value
}
