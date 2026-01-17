import AppKit

struct MarqueeView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKState private var marqueeRect: CGRect?
    @CKState private var origin: CGPoint?
    @CKState private var isAdditive: Bool = false

    var marqueeColor: CGColor {
        environment.canvasTheme.crosshairColor
    }

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

    var body: some CKView {
        CKGroup {
            if let rect = marqueeRect {
                marqueeRect(rect)
            } else {
                CKEmpty()
            }
        }
        .onCanvasDrag(handleMarqueeDrag)
    }

    private func marqueeRect(_ rect: CGRect) -> some CKView {
        let dashPattern: [CGFloat] = [4 * strokeWidth, 2 * strokeWidth]

        return CKRectangle(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .fill(marqueeColor.copy(alpha: 0.1) ?? .clear)
            .stroke(marqueeColor, width: strokeWidth)
            .lineCap(.butt)
            .lineJoin(.miter)
            .lineDash(dashPattern)
    }

    private func handleMarqueeDrag(
        _ phase: CanvasGlobalDragPhase,
        context: RenderContext,
        controller: CanvasController
    ) {
        switch phase {
        case .began(let event):
            guard controller.selectedTool is CursorTool else { return }
            guard context.hitTargets.hitTest(event.rawLocation) == nil else { return }

            isAdditive = event.event.modifierFlags.contains(.shift)
            origin = event.rawLocation
            marqueeRect = CGRect(origin: event.rawLocation, size: .zero)
            controller.view?.requestLayerUpdate()
        case .changed(let event):
            guard let origin = origin else { return }
            let marqueeRect = CGRect(origin: origin, size: .zero)
                .union(CGRect(origin: event.rawLocation, size: .zero))
            self.marqueeRect = marqueeRect
            controller.view?.requestLayerUpdate()

            let rawHits = context.hitTargets.hitTestAll(in: marqueeRect)
            controller.setInteractionHighlight(itemIDs: Set(rawHits), needsDisplay: false)
        case .ended(_):
            guard origin != nil else { return }
            let highlightedIDs = controller.highlightedItemIDs
            let finalSelection = isAdditive
                ? context.selectedItemIDs.union(highlightedIDs)
                : Set(highlightedIDs)
            if finalSelection != context.selectedItemIDs {
                controller.updateSelection(finalSelection)
            }

            origin = nil
            isAdditive = false
            marqueeRect = nil
            controller.view?.requestLayerUpdate()
            controller.setInteractionHighlight(itemIDs: [], needsDisplay: false)
        }
    }
}
