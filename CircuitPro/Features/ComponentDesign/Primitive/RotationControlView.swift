//
//  RotationControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct RotationControlView<T: Transformable>: View {
    @Binding var object: T

    // This is our adapter binding. It encapsulates all the logic to translate
    // between the model's data (radians, CW) and the UI's representation (degrees, CCW).
    private var rotationInDegrees: Binding<CGFloat> {
        Binding<CGFloat>(
            get: {
                // Convert model's rotation (radians, positive is CW) to UI's value (degrees, positive is CCW)
                let degrees = -object.rotation * 180 / .pi
                // Normalize to a positive 0-360 range for the slider UI
                return (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            },
            set: { newValueInDegrees in
                // Convert UI's value (degrees, positive is CCW) back to the model's rotation (radians, positive is CW)
                let modelDegrees = -newValueInDegrees
                object.rotation = modelDegrees * .pi / 180
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Rotation").font(.headline)
            HStack(spacing: 8) {
                // The RadialSlider uses our adapter binding
                RadialSlider(
                    value: rotationInDegrees,
                    range: 0...360,
                    isContinuous: true
                )
                .frame(width: 60, height: 60)

                // The DoubleField ALSO uses the exact same adapter binding,
                // ensuring they are perfectly in sync.
                FloatingPointField(
                    title: "", // Title is provided by the Text view above
                    value: rotationInDegrees,
                    maxDecimalPlaces: 1
                )
                .frame(width: 70) // Give it a specific width
                
                Text("deg")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
