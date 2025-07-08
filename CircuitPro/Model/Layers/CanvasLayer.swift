import SwiftUI

/// Generic layer description used by ``CanvasView``.
/// When no specific layer information is supplied, ``layer0`` is used.
struct CanvasLayer: Hashable {
    /// Z position in the stack (0 is bottom)
    var zPosition: Int
    /// Display color for primitives placed on this layer
    var color: Color
    /// Optional PCB-specific kind when applicable
    var kind: LayerKind?

    init(zPosition: Int, color: Color = .gray, kind: LayerKind? = nil) {
        self.zPosition = zPosition
        self.color = color
        self.kind = kind
    }
}

extension CanvasLayer {
    /// Default layer used when no layering information is provided.
    static let layer0 = CanvasLayer(zPosition: 0)

    /// Convenience initializer to build a ``CanvasLayer`` from ``LayerKind``.
    init(kind: LayerKind) {
        self.init(zPosition: 0, color: kind.defaultColor, kind: kind)
    }
}
