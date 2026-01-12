import AppKit

struct MarqueeRL: CKView {
    @CKContext var context

    var marqueeColor: CGColor {
        context.environment.canvasTheme.crosshairColor
    }

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

    var body: some CKView {
        CKGroup {
            if let rect = context.environment.marqueeRect {
                marqueeRect(rect)
            } else {
                CKEmpty()
            }
        }
        .onCanvasDrag(handleMarqueeDrag)
    }

    private func marqueeRect(_ rect: CGRect) -> some CKView {
        let dashPattern: [CGFloat] = [4 * strokeWidth, 2 * strokeWidth]

        return CKRectangle()
            .frame(width: rect.width, height: rect.height)
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
        let state = context.environment.marqueeDragState

        switch phase {
        case .began(let event):
            guard controller.selectedTool is CursorTool else { return }
            guard context.hitTargets.hitTest(event.rawLocation) == nil else { return }

            let isAdditive = event.event.modifierFlags.contains(.shift)
            state.begin(origin: event.rawLocation, isAdditive: isAdditive)
            controller.updateEnvironment {
                $0.marqueeRect = CGRect(origin: event.rawLocation, size: .zero)
            }
        case .changed(let event):
            guard let origin = state.origin else { return }
            let marqueeRect = CGRect(origin: origin, size: .zero)
                .union(CGRect(origin: event.rawLocation, size: .zero))
            controller.updateEnvironment {
                $0.marqueeRect = marqueeRect
            }

            let rawHits = context.hitTargets.hitTestAll(in: marqueeRect)
            controller.setInteractionHighlight(itemIDs: Set(rawHits))
        case .ended(_):
            guard state.origin != nil else { return }
            let highlightedIDs = controller.highlightedItemIDs
            let finalSelection = state.isAdditive
                ? context.selectedItemIDs.union(highlightedIDs)
                : Set(highlightedIDs)
            if finalSelection != context.selectedItemIDs {
                controller.updateSelection(finalSelection)
            }

            state.reset()
            controller.updateEnvironment { $0.marqueeRect = nil }
            controller.setInteractionHighlight(itemIDs: [])
        }
    }
}
