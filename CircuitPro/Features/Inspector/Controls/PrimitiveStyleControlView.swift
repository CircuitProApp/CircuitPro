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
    
    private var cornerRadiusBinding: Binding<CGFloat>? {

        guard var rect = $object.wrappedValue as? RectanglePrimitive else {
            return nil
        }
        
        return Binding<CGFloat>(
            get: { rect.cornerRadius },
            set: { newValue in
                rect.cornerRadius = newValue
                $object.wrappedValue = rect as! T
            }
        )
    }
    
    var body: some View {
        InspectorSection("Style") {
            InspectorRow("Stroke") {
              
                    InspectorNumericField(
                        title: "W",
                        value: $object.strokeWidth,
                        range: 0...100,
                        displayMultiplier: 0.1,
                        unit: "mm"
                    )
                    .disabled(isFillable && object.filled)
                    Color.clear
                
            }
            if isFillable {
                InspectorRow("Filled") {
                    Toggle("Filled", isOn: $object.filled)
                        .labelsHidden()
                }
            }
            
            if let cornerRadius = cornerRadiusBinding {
                InspectorRow("Corners") {
             
                        Slider(value: cornerRadius, in: 0...(($object.wrappedValue as! RectanglePrimitive).maximumCornerRadius))
                            .controlSize(.small)
                        InspectorNumericField(
                            value: cornerRadius,
                            range: 0...(($object.wrappedValue as! RectanglePrimitive).maximumCornerRadius),
                            maxDecimalPlaces: 1
                        )
                }
            }
        }
    }
}
