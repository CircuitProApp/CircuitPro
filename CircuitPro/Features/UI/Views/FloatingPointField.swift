//
//  FloatingPointField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct FloatingPointField<T: BinaryFloatingPoint>: View {
    // 1. Properties
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
    
    // Optional suffix for units like "mm" or "°"
    var suffix: String?
    
    var titleDisplayMode: TitleDisplayMode = .overlay

    // 2. State
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    enum TitleDisplayMode {
        case label
        case overlay
    }

    // 3. Body
    var body: some View {
        HStack {
            if titleDisplayMode == .label {
                Text(title)
                    .font(.subheadline)
            }
          
            TextField("", text: $text)
                .frame(width: 50)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .directionalPadding(vertical: 2.5, horizontal: 5)
                .padding(.trailing, titleDisplayMode == .overlay ? 12.5 : 0)
                .background(.ultraThinMaterial)
                .clipAndStroke(with: .rect(cornerRadius: 5))
                .overlay(alignment: .trailing) {
                    if titleDisplayMode == .overlay {
                        Text(title)
                            .font(.caption)
                            .padding(.horizontal, 5)
                    }
                }
                .focusRing(isFocused, shape: .rect(cornerRadius: 5))
                .onAppear {
                    let displayValue = (value * displayMultiplier) + displayOffset
                    text = formatted(displayValue)
                }
                .onChange(of: value) { _, newValue in
                    // Update text only if not focused to avoid disrupting user input
                    if !isFocused {
                        let displayValue = (newValue * displayMultiplier) + displayOffset
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
    }

    // 4. Private Methods
    private func validateAndCommit() {
        // MODIFIED: Logic to strip the suffix before validation.
        
        // 1. Prepare the input string by trimming whitespace.
        var inputText = text.trimmingCharacters(in: .whitespaces)
        
        // 2. If a suffix exists, remove it from the end of the input string.
        if let suffix = suffix, !suffix.isEmpty, inputText.hasSuffix(suffix) {
            inputText = String(inputText.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        }
        
        // 3. Filter the remaining string to ensure it's a valid number.
        let filtered = filterInput(inputText)
        
        // 4. Attempt to convert the filtered string to our numeric type.
        if let doubleVal = Double(filtered) {
            let genericVal = T(doubleVal)

            let internalValue = (genericVal - displayOffset) / displayMultiplier
            let clamped = clamp(internalValue, to: range)
            value = clamped // Commit the valid value
            
            // Re-format the text with the suffix for display consistency.
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
        // MODIFIED: Appends the suffix to the formatted number string.
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = maxDecimalPlaces
        formatter.minimumIntegerDigits = 1
        
        let numberString = formatter.string(from: NSNumber(value: Double(value))) ?? ""
        
        // Append a space and the suffix if it exists.
        if let suffix = suffix, !suffix.isEmpty {
            return "\(numberString) \(suffix)"
        } else {
            return numberString
        }
    }
}
