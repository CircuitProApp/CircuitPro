import AppKit

struct HandlesRL: CKView {
    @CKContext var context

    @CKViewBuilder var body: some CKView {
        if let graphHandle = findEditable(in: context) {
            handlesLayer(handles: graphHandle.handles, transform: graphHandle.transform)
        } else {
            CKEmpty()
        }
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

    @CKViewBuilder private func handlesLayer(
        handles: [CanvasHandle],
        transform: CGAffineTransform
    ) -> some CKView {
        if handles.isEmpty {
            CKEmpty()
        } else {
            let handleScreenSize: CGFloat = 10.0
            let sizeInWorldCoords = handleScreenSize / max(context.magnification, .ulpOfOne)
            let half = sizeInWorldCoords / 2.0
            let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

            let path = handlesPath(
                handles: handles,
                transform: transform,
                half: half,
                sizeInWorldCoords: sizeInWorldCoords
            )

            CKPath(path: path)
                .fill(NSColor.white.cgColor)
                .stroke(NSColor.systemBlue.cgColor, width: lineWidth)
        }
    }

    private func handlesPath(
        handles: [CanvasHandle],
        transform: CGAffineTransform,
        half: CGFloat,
        sizeInWorldCoords: CGFloat
    ) -> CGPath {
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
        return path
    }
}
