//
//  RotationControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct RotationControlView<T: Transformable>: View {
    
    @Binding var object: T
    
    var tickCount: Int? = nil
    var tickStepDegrees: CGFloat?
    var snapsToTicks: Bool = false
    
    
    private var rotationInDegrees: Binding<CGFloat> {
        Binding(
            get: {
                let degrees = object.rotation * 180 / .pi
                return (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            },
            set: {
                object.rotation = $0 * .pi / 180
            }
        )
    }
    
    var body: some View {
        InspectorRow("Rotate") {
            RadialSlider(
                value: rotationInDegrees,
                range: 0...360,
                zeroAngle: .east,
                isContinuous: true,
                tickCount: tickCount,
                tickStepDegrees: tickStepDegrees,
                snapsToTicks: snapsToTicks
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            InspectorNumericField(
                value: rotationInDegrees,
                maxDecimalPlaces: 1,
                unit: "°",
                alignment: .center
            )
        }
    }
}
