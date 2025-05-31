import SwiftUI
import SwiftData

struct SchematicView: View {
    var canvasManager: CanvasManager = CanvasManager()
    var body: some View {
        VStack {
            Text("Schematic View")
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
        }
    }
}

#Preview {
    SchematicView()
}
