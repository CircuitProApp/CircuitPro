//
//  NumericField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct NumericField<T: NumericType>: View {

    @Binding var value: T
    var placeholder: String = ""
    var range: ClosedRange<T>?
    var allowNegative: Bool = true
    
    /// The maximum number of decimal places to allow and display.
    /// If nil, it defaults to 0 for Integers and 3 for floating-point types.
    var maxDecimalPlaces: Int?
    
    /// Multiplier applied to the internal value for display (e.g., storing meters, displaying millimeters).
    var displayMultiplier: T = 1
    /// Constant added to the scaled value for display.
    var displayOffset: T = 0
    
    // Optional suffix for units like "mm" or "°".
    var suffix: String?
    
    // The focus state is passed from the parent view.
    var isFocused: FocusState<Bool>.Binding

    // 3.2. State
    @State private var text: String = ""

    // 3.3. Computed Properties
    private var isInteger: Bool { T.self == Int.self }
    
    private var effectiveMaxDecimalPlaces: Int {
        if let maxDecimalPlaces = maxDecimalPlaces {
            return isInteger ? 0 : maxDecimalPlaces
        }
        return isInteger ? 0 : 3
    }

    // 3.4. Body
    var body: some View {
        TextField(placeholder, text: $text)
            .focused(isFocused)
            .onAppear {
                let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
                text = formatted(displayValue)
            }
            .onChange(of: value) { _, newValue in
                // Update text only if not focused to avoid disrupting user input.
                if !isFocused.wrappedValue {
                    let displayValue = (newValue.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
                    text = formatted(displayValue)
                }
            }
            .onChange(of: range) { _, newRange in
                // When the range changes, ensure the current value is still valid.
                let clamped = clamp(value, to: newRange)
                if clamped != value {
                    value = clamped
                }
            }
            .onChange(of: isFocused.wrappedValue) { _, focused in
                if !focused {
                    validateAndCommit()
                }
            }
            .onSubmit {
                validateAndCommit()
                isFocused.wrappedValue = false
            }
    }

    // 4. Private Methods
    private func validateAndCommit() {
        // 1. Prepare input string.
        var inputText = text.trimmingCharacters(in: .whitespaces)
        
        // 2. Remove suffix if it exists.
        if let suffix = suffix, !suffix.isEmpty, inputText.hasSuffix(suffix) {
            let chopped = String(inputText.dropLast(suffix.count))
            // Also trim potential space before the suffix, e.g., "123.4 mm"
            inputText = chopped.trimmingCharacters(in: .whitespaces)
        }
        
        // 3. Filter the string to ensure it's a valid number.
        let filtered = filterInput(inputText)
        
        // 4. Attempt to convert filtered string to a number.
        if let doubleVal = Double(filtered) {
            // Apply inverse display transform to get the internal value.
            // All calculations are done in Double precision for consistency.
            let internalValueDouble = (doubleVal - displayOffset.doubleValue) / displayMultiplier.doubleValue
            
            // Convert back to the generic type T and clamp.
            let internalValue = T(internalValueDouble)
            let clamped = clamp(internalValue, to: range)
            value = clamped // Commit the valid value.
            
            // Re-format the text with the suffix for display consistency.
            let displayValue = (clamped.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
            text = formatted(displayValue)
        } else {
            // If input is invalid, revert to the last known good value.
            let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
            text = formatted(displayValue)
        }
    }

    private func filterInput(_ input: String) -> String {
        // Allow numbers, negative sign, and a single decimal point (if not an integer).
        var allowedChars = CharacterSet(charactersIn: "0123456789-")
        if !isInteger {
            allowedChars.insert(".")
        }
        
        var result = input.components(separatedBy: allowedChars.inverted).joined()

        // Ensure negative sign is only at the start.
        if allowNegative {
            if result.first == "-" {
                result = "-" + result.dropFirst().filter { $0 != "-" }
            } else {
                result = result.filter { $0 != "-" }
            }
        } else {
            result.removeAll { $0 == "-" }
        }

        // Handle decimal places for non-integer types.
        if !isInteger {
            let decimalParts = result.split(separator: ".")
            if decimalParts.count > 2 {
                result = decimalParts.prefix(2).joined(separator: ".")
            }
            
            if let dotIndex = result.firstIndex(of: "."), effectiveMaxDecimalPlaces > 0 {
                let afterDecimal = result[result.index(after: dotIndex)...]
                if afterDecimal.count > effectiveMaxDecimalPlaces {
                    result = String(result.prefix(upTo: dotIndex)) + "." + afterDecimal.prefix(effectiveMaxDecimalPlaces)
                }
            }
        }

        return result
    }

    private func clamp(_ x: T, to bounds: ClosedRange<T>?) -> T {
        guard let bounds else { return x }
        return min(max(x, bounds.lowerBound), bounds.upperBound)
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        // Set minimum fraction digits to 0 so we don't show ".0" for whole numbers.
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = effectiveMaxDecimalPlaces
        
        let numberString = formatter.string(from: NSNumber(value: value)) ?? ""
        
        if let suffix = suffix, !suffix.isEmpty {
            return "\(numberString) \(suffix)"
        } else {
            return numberString
        }
    }
}
