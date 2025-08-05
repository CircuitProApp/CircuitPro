import SwiftUI

/// Wrapper for layer-related bindings passed to ``CanvasView``.
struct CanvasLayerBindings {
    var selectedLayer: Binding<CanvasLayer?>
    var layerAssignments: Binding<[UUID: CanvasLayer]>
}
