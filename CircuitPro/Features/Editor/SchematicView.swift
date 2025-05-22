import SwiftUI
import SwiftData

struct SchematicView: View {
    @State private var canvasManager: CanvasManager = CanvasManager()
    var body: some View {
        VStack {
            Text("Schematic View")
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .overlay {
                    CanvasOverlayView()
                }
        }
        .environment(canvasManager)
    }
}

#Preview {
    SchematicView()
}
