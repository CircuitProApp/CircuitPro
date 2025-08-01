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
    
    // Styling properties
    var titleDisplayMode: TitleDisplayMode = .integrated
    
    enum TitleDisplayMode {
        case integrated
        case hidden
    }
    
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            NumericField(
                value: $value,
                placeholder: placeholder,
                range: range,
                allowNegative: allowNegative,
                maxDecimalPlaces: maxDecimalPlaces,
                displayMultiplier: displayMultiplier,
                displayOffset: displayOffset,
                suffix: suffix,
                isFocused: $isFieldFocused
            )
            
            if titleDisplayMode == .integrated, let title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .inspectorField()
        
    }
}
