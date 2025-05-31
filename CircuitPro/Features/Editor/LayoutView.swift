import SwiftUI

struct LayoutView: View {
    var canvasManager: CanvasManager = CanvasManager()
    var body: some View {
        VStack {
            Text("Layout View")
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
    }
}

#Preview {
    LayoutView()
}
