import SwiftUI

struct ComponentDesignSuccessView: View {
    var onClose: () -> Void
    var onCreateAnother: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            Image(systemName: CircuitProSymbols.Generic.checkmark.appending(".seal.fill"))
                .font(.system(size: 100))
                .foregroundStyle(.white, .green.gradient)
            Text("Component created successfully")
                .font(.title)
                .foregroundStyle(.primary)
            HStack {
                Button("Close Window", action: onClose)
                Button("Create Another", action: onCreateAnother)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
