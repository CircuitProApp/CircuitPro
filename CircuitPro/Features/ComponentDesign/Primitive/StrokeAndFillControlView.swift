//
//  StrokeAndFillControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct StrokeAndFillControlView<T: GraphicPrimitive>: View {
    @Binding var object: T

    // 1. Compute whether the object is fillable based on its generic type.
    // This check happens at compile-time.
    private var isFillable: Bool {
        // The view can only be filled if its type is NOT LinePrimitive.
        return T.self != LinePrimitive.self
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style").font(.headline)
            
            // 2. The conditional UI now uses our internal computed property.
            if isFillable {
                Toggle("Filled", isOn: $object.filled)
            }
            
            FloatingPointField(
                title: "Stroke Width",
                value: $object.strokeWidth,
                range: 0...100
            )
            // 3. The disable logic also uses the internal property.
            .disabled(isFillable && object.filled)
        }
    }
}
