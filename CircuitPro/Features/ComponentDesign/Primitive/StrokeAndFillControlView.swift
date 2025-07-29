//
//  StrokeAndFillControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct StrokeAndFillControlView<T: GraphicPrimitive>: View {

    @Binding var object: T

    private var isFillable: Bool {
        return T.self != LinePrimitive.self
    }

    var body: some View {
        InspectorSection(title: "Style") {
            VStack(alignment: .trailing) {
                FloatingPointField(
                    title: "Stroke Width",
                    value: $object.strokeWidth,
                    range: 0...100,
                    titleDisplayMode: .label
                )
                .disabled(isFillable && object.filled)
                
                if isFillable {
                    Toggle("Filled", isOn: $object.filled)
                        .font(.subheadline)
                        .toggleStyle(.button)
                }
            }
        }
    }
}
