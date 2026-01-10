import AppKit

struct HandlesRL: CKRenderLayer {
    @CKContext var context

    var body: CKLayer {
        guard let graphHandle = findEditable(in: context) else {
            return .empty
        }
        return handlesLayer(handles: graphHandle.handles, transform: graphHandle.transform)
    }

    private func findEditable(in context: RenderContext) -> (handles: [CanvasHandle], transform: CGAffineTransform)? {
        let selectionIDs = context.selectedItemIDs
        guard selectionIDs.count == 1, let selectedID = selectionIDs.first else { return nil }

        let primitive = context.items.first(where: { $0.id == selectedID }) as? AnyCanvasPrimitive
        guard let primitive else { return nil }

        let transform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
            .rotated(by: primitive.rotation)
        return (primitive.handles(), transform)
    }

    private func handlesLayer(handles: [CanvasHandle], transform: CGAffineTransform) -> CKLayer {
        guard !handles.isEmpty else { return .empty }

        let handleScreenSize: CGFloat = 10.0
        let sizeInWorldCoords = handleScreenSize / max(context.magnification, .ulpOfOne)
        let half = sizeInWorldCoords / 2.0
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

        let path = CGMutablePath()
        for handle in handles {
            let worldHandlePosition = handle.position.applying(transform)
            let handleRect = CGRect(
                x: worldHandlePosition.x - half,
                y: worldHandlePosition.y - half,
                width: sizeInWorldCoords,
                height: sizeInWorldCoords
            )
            path.addEllipse(in: handleRect)
        }

        return CKPath(path: path)
            .fill(NSColor.white.cgColor)
            .stroke(NSColor.systemBlue.cgColor, width: lineWidth)
            .layer
    }
}
