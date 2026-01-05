import AppKit
import Foundation

struct PCBLayer: CanvasLayer {
    let id: UUID
    var name: String
    var isVisible: Bool
    var color: CGColor
    var zIndex: Int
    var layerKind: LayerKind?
    var layerSide: LayerSide?

    init(
        id: UUID = UUID(),
        name: String,
        isVisible: Bool = true,
        color: CGColor,
        zIndex: Int,
        layerKind: LayerKind? = nil,
        layerSide: LayerSide? = nil
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.color = color
        self.zIndex = zIndex
        self.layerKind = layerKind
        self.layerSide = layerSide
    }

    init(layerType: LayerType, isVisible: Bool = true) {
        self.init(
            id: layerType.id,
            name: layerType.name,
            isVisible: isVisible,
            color: NSColor(layerType.defaultColor).cgColor,
            zIndex: layerType.kind.zIndex,
            layerKind: layerType.kind,
            layerSide: layerType.side
        )
    }

    init(kind: LayerKind, isVisible: Bool = true) {
        self.init(
            id: kind.stableId,
            name: kind.label,
            isVisible: isVisible,
            color: NSColor(kind.defaultColor).cgColor,
            zIndex: kind.zIndex,
            layerKind: kind,
            layerSide: nil
        )
    }
}

extension PCBLayer: Hashable {
    static func == (lhs: PCBLayer, rhs: PCBLayer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
