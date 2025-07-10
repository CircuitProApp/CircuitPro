import SwiftUI

struct ComponentDesignSuccessView: View {
    var onClose: () -> Void
    var onCreateAnother: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: CircuitProSymbols.Generic.checkmark)
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.primary, .green.gradient)
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
