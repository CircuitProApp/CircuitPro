import SwiftUI

/// Generic layer description used by ``CanvasView``.
/// When no specific layer information is supplied, ``layer0`` is used.
struct CanvasLayer: Hashable {
    /// Z-index in the stack (0 is bottom)
    var zIndex: Int
    /// Display color for primitives placed on this layer
    var color: Color
    /// Optional PCB-specific kind when applicable
    var kind: LayerKind?

    init(zIndex: Int, color: Color = .blue, kind: LayerKind? = nil) {
        self.zIndex = zIndex
        self.color = color
        self.kind = kind
    }
}

extension CanvasLayer {
    /// Default layer used when no layering information is provided.
    static let layer0 = CanvasLayer(zIndex: 0)

    /// Convenience initializer to build a ``CanvasLayer`` from ``LayerKind``.
    init(kind: LayerKind) {
        self.init(zIndex: kind.zIndex, color: kind.defaultColor, kind: kind)
    }
}
