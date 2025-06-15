import SwiftUI
import SwiftData

@Model
final class Layout {
    var title: String
    var timestamps: Timestamps

    @Relationship(deleteRule: .cascade, inverse: \Layer.layout)
    var layers: [Layer] = []

    @Relationship(deleteRule: .cascade, inverse: \Via.layout)
    var vias: [Via] = []

    var design: Design?

    init(title: String, design: Design? = nil) {
        self.title = title
        self.design = design
        self.timestamps = Timestamps()
    }
}

extension Layout {
    func populateDefaultLayers() {
        for layerType in LayerType.defaultLayerTypes {
            let layer = Layer(
                type: layerType,
                layout: self,
                color: SDColor(color: layerType.defaultColor)
            )
            self.layers.append(layer)
        }
    }
}
