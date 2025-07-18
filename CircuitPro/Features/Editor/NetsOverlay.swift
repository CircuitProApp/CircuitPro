import SwiftUI

struct NetsOverlay: View {
    @Binding var graph: SchematicGraph
    let nets: [SchematicGraph.Net]

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Disconnected Nets (\(nets.count))")
                    .font(.headline)
                Spacer()
                Button("Clear All", role: .destructive) {
                    graph.clear()
                }
            }
            
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(nets) { net in
                        HStack {
                            Text("Net \(net.id.uuidString.prefix(8))")
                            Spacer()
                            Text("\(net.vertexCount) vertices, \(net.edgeCount) edges")
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .padding()
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(10)
    }
}
