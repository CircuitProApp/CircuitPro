//
//  AdjustedForMagnification.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/30/25.
//

import SwiftUI

struct AdjustedForMagnification: ViewModifier {
    @Environment(CanvasManager.self)
    private var canvasManager

    var bounds: ClosedRange<Double> = 1.0...Double.infinity

    func body(content: Content) -> some View {
        let rawMagnification = canvasManager.magnification
        let clampedMagnification = bounds.clamp(rawMagnification)

        return content
            .scaleEffect(1 / clampedMagnification, anchor: .center)
    }
}

extension View {
    func adjustedForMagnification(bounds: ClosedRange<Double> = 1.0...Double.infinity) -> some View {
        self.modifier(AdjustedForMagnification(bounds: bounds))
    }
}
