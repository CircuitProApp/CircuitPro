//
//  InspectorNumericField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

struct InspectorNumericField<T: NumericType>: View {

    var title: String?
    @Binding var value: T
    
    var placeholder: String = ""
    var range: ClosedRange<T>?
    var allowNegative: Bool = true
    var maxDecimalPlaces: Int = 3
    var displayMultiplier: T = 1
    var displayOffset: T = 0
    var suffix: String?
    var unit: String?
    
    var alignment: VerticalAlignment = .lastTextBaseline
    
    var body: some View {
        HStack(spacing: 5) { // This HStack defaults to .center alignment
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Group the field and its unit into a new HStack for special alignment
            HStack(alignment: alignment, spacing: 5) {
                NumericField(
                    value: $value,
                    placeholder: placeholder,
                    range: range,
                    allowNegative: allowNegative,
                    maxDecimalPlaces: maxDecimalPlaces,
                    displayMultiplier: displayMultiplier,
                    displayOffset: displayOffset,
                    suffix: suffix
                )
                .multilineTextAlignment(.trailing)
                
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .inspectorField()
    }
}
