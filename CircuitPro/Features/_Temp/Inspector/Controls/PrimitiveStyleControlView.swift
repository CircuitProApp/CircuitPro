//
//  PrimitiveStyleControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct PrimitiveStyleControlView<T: CanvasPrimitive>: View {
    @Binding var object: T

    /// A private computed property to determine if the primitive supports filling.
    /// This now correctly checks against `CanvasLine.self`.
    private var isFillable: Bool {
        return T.self != CanvasLine.self
    }

    /// A computed property that safely provides the necessary data for corner radius controls.
    /// It returns `nil` if the object is not a `CanvasRectangle`, hiding the controls.
    private var cornerRadiusData: (binding: Binding<CGFloat>, range: ClosedRange<CGFloat>)? {
        // 1. Guard that the generic type T is actually a CanvasRectangle.
        //    If it's not, we return nil, and the UI for corner radius won't be created.
        guard let rect = object as? CanvasRectangle else {
            return nil
        }

        // 2. Determine the valid range for the corner radius based on the rectangle's current size.
        let range = 0...rect.maximumCornerRadius

        // 3. Create a custom, safe binding to the corner radius property.
        let binding = Binding<CGFloat>(
            get: {
                // Read the value directly from the source of truth (`object`).
                // This cast is safe because of the guard above.
                (object as! CanvasRectangle).cornerRadius
            },
            set: { newValue in
                // To update the value, we must modify a copy of the struct...
                var rectToUpdate = object as! CanvasRectangle
                // ...clamping the new value to the valid range...
                rectToUpdate.cornerRadius = max(range.lowerBound, min(newValue, range.upperBound))
                // ...and then assign the entire modified struct back to the binding.
                object = rectToUpdate as! T
            }
        )

        return (binding, range)
    }

    var body: some View {
        InspectorSection("Style") {
            // This control is disabled if the shape is fillable AND filled.
            InspectorRow("Stroke", style: .leading) {
                InspectorNumericField(
                    label: "W",
                    value: $object.strokeWidth,
                    range: 0...100,
                    displayMultiplier: 0.1,
                    unit: "mm"
                )
                .disabled(isFillable && object.filled)

            }

            // The "Filled" toggle only appears for fillable shapes like rectangles and circles.
            if isFillable {
                InspectorRow("Filled") {
                    Toggle("Filled", isOn: $object.filled)
                        .labelsHidden()
                }
            }

            // The corner radius controls only appear if `cornerRadiusData` is not nil.
            // This check ensures we only show this UI for `CanvasRectangle`.
            if let cornerData = cornerRadiusData {
                InspectorRow("Corners") {
                    Slider(value: cornerData.binding, in: cornerData.range)
                        .controlSize(.small)
                    InspectorNumericField(
                        value: cornerData.binding,
                        range: cornerData.range,
                        maxDecimalPlaces: 1
                    )
                }
            }
        }
    }
}
