import AppKit

struct PolylineView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let polyline: CanvasPolyline
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(polyline.id) ||
            context.selectedItemIDs.contains(polyline.id)
    }

    var body: some CKView {
        let path = PrimitiveGeometry.localPath(for: .polyline(polyline))
        CKGroup {
            CKPath(path: path)
                .fill(polyline.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: polyline.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == polyline.layerId }?.color
            ?? environment.canvasTheme.textColor
    }
}
