import SwiftUI

struct IntegerField: View {
    let title: String
    @Binding var value: Int
    var placeholder: String = ""
    var range: ClosedRange<Int>? = nil
    var allowNegative: Bool = false

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $text)
            .focused($isFocused)
            .onAppear {
                text = String(value)
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
        if let intVal = Int(filtered) {
            let clamped = clamp(intVal, to: range)
            value = clamped
            text = String(clamped)
        } else {
            text = String(value) // reset to last valid value
        }
    }

    private func filterInput(_ input: String) -> String {
        var result = input.filter { $0.isNumber || $0 == "-" }

        // Enforce at most one leading minus
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

    private func clamp(_ x: Int, to bounds: ClosedRange<Int>?) -> Int {
        guard let bounds else { return x }
        return min(max(x, bounds.lowerBound), bounds.upperBound)
    }
}
