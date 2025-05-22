import SwiftUI

struct DoubleField: View {
    let title: String
    @Binding var value: Double
    var placeholder: String = ""
    var range: ClosedRange<Double>? = nil
    var allowNegative: Bool = true
    var maxDecimalPlaces: Int = 3

    /// Multiplier applied to internal value for display (e.g., 0.1 means 10 points = 1 mm)
    var displayMultiplier: Double = 1.0

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .onAppear {
                text = formatted(value * displayMultiplier)
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
        if let doubleVal = Double(filtered) {
            let internalValue = doubleVal / displayMultiplier
            let clamped = clamp(internalValue, to: range)
            value = clamped
            text = formatted(clamped * displayMultiplier)
        } else {
            text = formatted(value * displayMultiplier)
        }
    }

    private func filterInput(_ input: String) -> String {
        var result = input.filter { $0.isNumber || $0 == "." || $0 == "-" }

        let decimalParts = result.split(separator: ".")
        if decimalParts.count > 2 {
            result = decimalParts.prefix(2).joined(separator: ".")
        }

        if let dotIndex = result.firstIndex(of: ".") {
            let afterDecimal = result[dotIndex...].dropFirst()
            if afterDecimal.count > maxDecimalPlaces {
                result = String(result.prefix(upTo: dotIndex)) + "." + afterDecimal.prefix(maxDecimalPlaces)
            }
        }

        if allowNegative {
            let hasMinus = result.contains("-")
            result.removeAll { $0 == "-" }
            if hasMinus {
                result = "-" + result
            }
        } else {
            result.removeAll { $0 == "-" }
        }

        return result
    }

    private func clamp(_ x: Double, to bounds: ClosedRange<Double>?) -> Double {
        guard let bounds else { return x }
        return min(max(x, bounds.lowerBound), bounds.upperBound)
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = maxDecimalPlaces
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
