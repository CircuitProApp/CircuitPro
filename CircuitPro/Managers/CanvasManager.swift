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

    var mouseLocation: CGPoint = .zero

    var enableSnapping: Bool = true
    var enableAxesBackground: Bool = true

    var crosshairsStyle: CrosshairsStyle = .centeredCross
    var backgroundStyle: CanvasBackgroundStyle = .dotted

    var showComponentDrawer: Bool = false

}
