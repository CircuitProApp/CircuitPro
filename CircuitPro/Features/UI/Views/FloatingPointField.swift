//
//  FloatingPointField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct FloatingPointField<T: BinaryFloatingPoint>: View {
    let title: String
    @Binding var value: T
    var placeholder: String = ""
    var range: ClosedRange<T>?
    var allowNegative: Bool = true
    var maxDecimalPlaces: Int = 3

    /// Multiplier applied to internal value for display (e.g., 0.1 means 10 points = 1 mm)
    var displayMultiplier: T = 1.0
    /// Constant added to the scaled value for display
    var displayOffset: T = 0.0

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .onAppear {
                let displayValue = (value * displayMultiplier) + displayOffset
                text = formatted(displayValue)
            }
            .onChange(of: value) { _, newValue in
                // Update text field if the binding value changes from outside
                let displayValue = (newValue * displayMultiplier) + displayOffset
                text = formatted(displayValue)
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    validateAndCommit()
                }
            }
            .onSubmit {
                validateAndCommit()
                isFocused = false
            }
    }

    private func validateAndCommit() {
        let filtered = filterInput(text)
        
        // 1. Convert the filtered string to a 'Double' first.
        if let doubleVal = Double(filtered) {
            // 2. Convert the Double to our generic type 'T'.
            let genericVal = T(doubleVal)

            let internalValue = (genericVal - displayOffset) / displayMultiplier
            let clamped = clamp(internalValue, to: range)
            value = clamped
            
            let displayValue = (clamped * displayMultiplier) + displayOffset
            text = formatted(displayValue)
        } else {
            // If input is invalid, revert to the last known good value.
            let displayValue = (value * displayMultiplier) + displayOffset
            text = formatted(displayValue)
        }
    }

    private func filterInput(_ input: String) -> String {
        var result = input.filter { $0.isNumber || $0 == "." || $0 == "-" }

        let decimalParts = result.split(separator: ".")
        if decimalParts.count > 2 {
            result = decimalParts.prefix(2).joined(separator: ".")
        }
        
        if let dotIndex = result.firstIndex(of: ".") {
            let afterDecimal = result[result.index(after: dotIndex)...]
            if afterDecimal.count > maxDecimalPlaces {
                result = String(result.prefix(upTo: dotIndex)) + "." + afterDecimal.prefix(maxDecimalPlaces)
            }
        }

        if allowNegative {
            if result.first == "-" {
                result = "-" + result.dropFirst().filter { $0 != "-" }
            } else {
                result = result.filter { $0 != "-" }
            }
        } else {
            result.removeAll { $0 == "-" }
        }

        return result
    }

    private func clamp(_ x: T, to bounds: ClosedRange<T>?) -> T {
        guard let bounds else { return x }
        return min(max(x, bounds.lowerBound), bounds.upperBound)
    }

    private func formatted(_ value: T) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = maxDecimalPlaces
        formatter.minimumIntegerDigits = 1
        // Convert T to Double for formatting, as NSNumber works reliably with it.
        return formatter.string(from: NSNumber(value: Double(value))) ?? ""
    }
}
