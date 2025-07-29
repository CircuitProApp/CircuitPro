//
//  RotationControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct RotationControlView<T: Transformable>: View {
    @Binding var object: T

    private var rotationInDegrees: Binding<CGFloat> {
        Binding(
            get: {
                let degrees = -object.rotation * 180 / .pi
                return (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            },
            set: {
                let modelDegrees = -$0
                object.rotation = modelDegrees * .pi / 180
            }
        )
    }

    var body: some View {
        InspectorSection(title: "Rotate") {
            RadialSlider(
                value: rotationInDegrees,
                range: 0...360,
                isContinuous: true
            )
            FloatingPointField(
                title: "",
                value: rotationInDegrees,
                maxDecimalPlaces: 1,
                suffix: "°"
            )
        }
    }
}
