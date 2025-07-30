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
    
    var maxDecimalPlaces: Int?
    var displayMultiplier: T = 1
    var displayOffset: T = 0
    var suffix: String?
    var isFocused: FocusState<Bool>.Binding

    @State private var text: String = ""

    private var isInteger: Bool { T.self == Int.self }
    
    private var effectiveMaxDecimalPlaces: Int {
        if let maxDecimalPlaces = maxDecimalPlaces {
            return isInteger ? 0 : maxDecimalPlaces
        }
        return isInteger ? 0 : 3
    }
    
    // This custom binding is the core of the solution.
    // It separates the text representation for display from the text for editing.
    private var textBinding: Binding<String> {
        Binding<String>(
            get: {
                // If focused, show the user's live input from our @State buffer.
                if isFocused.wrappedValue {
                    return text
                } else {
                    // If not focused, show the canonical, formatted value from the @Binding.
                    // This prevents feedback loops from external updates (e.g., a slider).
                    let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
                    return formatted(displayValue, forEditing: false)
                }
            },
            set: { newValue in
                // This is called by the TextField as the user types.
                // It only updates our local @State buffer during editing.
                self.text = newValue
            }
        )
    }

    var body: some View {
        TextField(placeholder, text: textBinding)
            .focused(isFocused)
            .onAppear {
                // On initial view appearance, set the text state from the canonical value.
                let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
                text = formatted(displayValue, forEditing: false)
            }
            .onChange(of: range) { _, newRange in
                let clamped = clamp(value, to: newRange)
                if clamped != value {
                    value = clamped
                }
            }
            .onChange(of: isFocused.wrappedValue) { _, focused in
                if focused {
                    // 1. Prepare text for editing when focus is GAINED.
                    // We use a simpler format (without the suffix) for a better UX.
                    let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
                    text = formatted(displayValue, forEditing: true)
                } else {
                    // 2. Commit changes when focus is LOST.
                    validateAndCommit()
                }
            }
            .onSubmit {
                validateAndCommit()
                isFocused.wrappedValue = false
            }
    }

    private func validateAndCommit() {
        var inputText = text.trimmingCharacters(in: .whitespaces)
        
        if let suffix = suffix, !suffix.isEmpty, inputText.hasSuffix(suffix) {
            let chopped = String(inputText.dropLast(suffix.count))
            inputText = chopped.trimmingCharacters(in: .whitespaces)
        }
        
        let filtered = filterInput(inputText)
        
        if let doubleVal = Double(filtered) {
            let internalValueDouble = (doubleVal - displayOffset.doubleValue) / displayMultiplier.doubleValue
            let internalValue = T(internalValueDouble)
            let clamped = clamp(internalValue, to: range)
            value = clamped
            
            let displayValue = (clamped.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
            text = formatted(displayValue, forEditing: false)
        } else {
            let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
            text = formatted(displayValue, forEditing: false)
        }
    }

    private func filterInput(_ input: String) -> String {
        var allowedChars = CharacterSet(charactersIn: "0123456789-")
        if !isInteger { allowedChars.insert(".") }
        var result = input.components(separatedBy: allowedChars.inverted).joined()

        if allowNegative {
            if result.first == "-" {
                result = "-" + result.dropFirst().filter { $0 != "-" }
            } else {
                result = result.filter { $0 != "-" }
            }
        } else {
            result.removeAll { $0 == "-" }
        }

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

    // Updated 'formatted' function to optionally exclude the suffix for a better editing UX.
    private func formatted(_ value: Double, forEditing: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = effectiveMaxDecimalPlaces
        
        let numberString = formatter.string(from: NSNumber(value: value)) ?? ""
        
        // Only add the suffix when not in editing mode.
        if let suffix = suffix, !suffix.isEmpty, !forEditing {
            return "\(numberString) \(suffix)"
        } else {
            return numberString
        }
    }
}
