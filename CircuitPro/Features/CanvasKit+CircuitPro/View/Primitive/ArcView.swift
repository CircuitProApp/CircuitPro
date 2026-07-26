import AppKit

struct ArcView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let arc: CanvasArc
    let isEditable: Bool

    var showHalo: Bool {
        context.highlightedItemIDs.contains(arc.id) ||
            context.selectedItemIDs.contains(arc.id)
    }

    var body: some CKView {
        let path = PrimitiveGeometry.localPath(for: .arc(arc))
        CKGroup {
            CKPath(path: path)
                .fill(arc.filled ? strokeColor : .clear)
                .stroke(strokeColor, width: arc.strokeWidth)
                .halo(showHalo ? .white.haloOpacity() : .clear, width: 5.0)
        }
    }

    private var strokeColor: CGColor {
        context.layers.first { $0.id == arc.layerId }?.color
            ?? environment.canvasTheme.textColor
    }
}
