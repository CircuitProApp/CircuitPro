//
//  PrimitiveStyleControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct PrimitiveStyleControlView<T: GraphicPrimitive>: View {

    @Binding var object: T

    private var isFillable: Bool {
        return T.self != LinePrimitive.self
    }

    var body: some View {
        InspectorSection(title: "Style") {
            InspectorRow(title: "Stroke Width") {
                InspectorNumericField(
                    title: "Stroke Width",
                    value: $object.strokeWidth,
                    range: 0...100,
                    titleDisplayMode: .hidden
                )
                .disabled(isFillable && object.filled)
            }
                
                if isFillable {
                    Toggle("Filled", isOn: $object.filled)
                        .font(.subheadline)
                        .toggleStyle(.button)
                }
            
        }
    }
}
