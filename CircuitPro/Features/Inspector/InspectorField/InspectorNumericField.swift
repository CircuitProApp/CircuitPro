//
//  InspectorNumericField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

enum InspectorNumericFieldLabelStyle {
    case regular
    case prominent
    
    var font: Font {
        switch self {
        case .regular:
            return .caption
        case .prominent:
            return .subheadline
        }
    }
    
    var color: Color {
        switch self {
        case .regular:
            return .secondary
        case .prominent:
            return .secondary.mix(with: .primary, by: 0.5)
        }
    }
}

struct InspectorNumericField<T: NumericType>: View {

    var label: String?
    @Binding var value: T
    
    var placeholder: String = ""
    var range: ClosedRange<T>?
    var allowNegative: Bool = true
    var maxDecimalPlaces: Int = 3
    var displayMultiplier: T = 1
    var displayOffset: T = 0
    var suffix: String?
    var unit: String?
    
    var labelStyle: InspectorNumericFieldLabelStyle = .regular
    
    var alignment: VerticalAlignment = .lastTextBaseline
    
    var body: some View {
        HStack(spacing: 5) { // This HStack defaults to .center alignment
            if let label {
                Text(label)
                    .font(labelStyle.font)
                    .foregroundColor(labelStyle.color)
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
