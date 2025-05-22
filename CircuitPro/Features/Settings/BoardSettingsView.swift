import SwiftUI

struct BoardSettingsView: View {
    let layers: [BoardLayer] = [
        .init(name: "Top Silkscreen", color: .white, thickness: 0.4),
        .init(name: "Top Solder Paste", color: .gray, thickness: 0.2),
        .init(name: "Top Solder Mask", color: .black, thickness: 1.0),
        .init(name: "Top Copper", color: .orange, thickness: 0.4),
        .init(name: "Dielectric", color: .green, thickness: 0.4),
        .init(name: "Bottom Copper", color: .orange, thickness: 0.2),
        .init(name: "Bottom Solder Mask", color: .black, thickness: 1.0),
        .init(name: "Bottom Solder paste", color: .gray, thickness: 0.4),
        .init(name: "Bottom Silkscreen", color: .white, thickness: 0.4),
    ]

    @State var visibleLayers: Double = 4

    var body: some View {
        HStack {
            ZStack {
                ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                    let visibleIndexStart = layers.count - Int(visibleLayers.rounded(.down))
                    if index >= visibleIndexStart {
                        LayerView(layer: layer)
                            .offset(x: 0, y: CGFloat(index - 2) * 15)
                            .zIndex(Double(layers.count - index))
                            .transition(.opacity)

                    }
                }
            }
            .frame(width: 400, height: 400)
            .animation(.easeInOut, value: visibleLayers)

            VerticalSlider(
                value: $visibleLayers,
                bounds: 1...Double(layers.count),
                tickMarks: layers.count,
                onlyAllowTickValues: true
            )
            .frame(width: 50, height: 200)
        }

    }
}

struct LayerView: View {
    var layer: BoardLayer

    var body: some View {

            Rectangle()
            .fill(layer.color)
            .stroke(layer.color.gradient)
            .frame(width: 200, height: 200)

            .rotationEffect(Angle(degrees: 45), anchor: .center)
            .scaleEffect(y: 0.4)

    }
}

struct BoardLayer: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let thickness: Double // mm
}

#Preview {
    BoardSettingsView()
}
