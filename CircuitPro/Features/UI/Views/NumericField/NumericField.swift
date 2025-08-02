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

    @State private var text: String = ""
    @FocusState private var isEditing: Bool

    private var isInteger: Bool { T.self == Int.self }

    private var effectiveMaxDecimalPlaces: Int {
        if let maxDecimalPlaces = maxDecimalPlaces {
            return isInteger ? 0 : maxDecimalPlaces
        }
        return isInteger ? 0 : 3
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .focused($isEditing)
            .onAppear {
                updateDisplayText()
            }
            .onChange(of: isEditing) { newFocus in
                if newFocus {
                    prepareTextForEditing()
                } else {
                    validateAndCommit()
                }
            }
            .onChange(of: range) { newRange in
                let clamped = clamp(value, to: newRange)
                if clamped != value {
                    value = clamped
                    updateDisplayText()
                }
            }
            .onSubmit {
                validateAndCommit()
                isEditing = false
            }
    }

    private func prepareTextForEditing() {
        let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
        text = formatted(displayValue, forEditing: true)
    }

    private func updateDisplayText() {
        let displayValue = (value.doubleValue * displayMultiplier.doubleValue) + displayOffset.doubleValue
        text = formatted(displayValue, forEditing: false)
    }

    private func validateAndCommit() {
        var inputText = text.trimmingCharacters(in: .whitespaces)
        
        if let suffix = suffix, !suffix.isEmpty, inputText.hasSuffix(suffix) {
            inputText = String(inputText.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }

        let filtered = filterInput(inputText)

        if let doubleVal = Double(filtered) {
            let internalValueDouble = (doubleVal - displayOffset.doubleValue) / displayMultiplier.doubleValue
            let internalValue = T(internalValueDouble)
            let clamped = clamp(internalValue, to: range)
            value = clamped
            updateDisplayText()
        } else {
            updateDisplayText()
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

    private func formatted(_ value: Double, forEditing: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = effectiveMaxDecimalPlaces
        
        let numberString = formatter.string(from: NSNumber(value: value)) ?? ""
        return (!forEditing && suffix != nil && !suffix!.isEmpty) ? "\(numberString) \(suffix!)" : numberString
    }
}
