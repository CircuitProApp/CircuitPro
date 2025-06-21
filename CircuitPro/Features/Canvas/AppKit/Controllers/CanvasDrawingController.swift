//  CanvasDrawingController.swift
import AppKit

final class CanvasDrawingController {

    unowned let canvas: CoreGraphicsCanvasView

    init(canvas: CoreGraphicsCanvasView) { self.canvas = canvas }
    // ---------------------------------------------------------------- draw
    func draw(in ctx: CGContext, dirtyRect: NSRect) {
        // Content — respects zoom
        ctx.saveGState()
        drawElements(in: ctx)
        drawLivePreview(in: ctx)
        ctx.restoreGState()
        // Overlay — screen space
        ctx.saveGState()
        drawHandles(in: ctx)
        ctx.restoreGState()
    }
    // MARK: - 1 elements + hit rects
    private func drawElements(in ctx: CGContext) {

        for element in canvas.elements {

            let selected = canvas.selectedIDs.contains(element.id)

            element.draw(in: ctx, selected: selected)

            if case let .pin(pin) = element {
                cacheHitRects(for: pin)
            }
        }
    }
    private func cacheHitRects(for pin: Pin) {

        let rects = pin.textHitRects()

        canvas.hitRects.pinNumberRects[pin.id] = rects.number
        canvas.hitRects.pinLabelRects[pin.id]  = rects.label
    }
    // MARK: - 2 live preview for the active tool
    private func drawLivePreview(in ctx: CGContext) {

        guard var tool = canvas.selectedTool, tool.id != "cursor", let win  = canvas.window else { return }

        let mouseWin = win.mouseLocationOutsideOfEventStream
        let mouse    = canvas.convert(mouseWin, from: nil)

        let pinCount = canvas.elements.reduce(0) { $1.isPin ? $0 + 1 : $0 }
        let padCount = canvas.elements.reduce(0) { $1.isPad ? $0 + 1 : $0 }

        let ctxInfo = CanvasToolContext(
            existingPinCount: pinCount,
            existingPadCount: padCount,
            selectedLayer: canvas.selectedLayer,
            magnification: canvas.magnification // <-- add this
        )

        let snappedMouse = canvas.snap(mouse)

        tool.drawPreview(in: ctx, mouse: snappedMouse, context: ctxInfo)
        canvas.selectedTool = tool               // persist mutated state
    }
    // MARK: - 3 selection handles
    private func drawHandles(in ctx: CGContext) {

        guard canvas.selectedIDs.count == 1 else { return }
        // --- NEW: scale is the inverse of the current magnification -------------
        let scale = 1 / canvas.magnification
        // ------------------------------------------------------------------------
        ctx.setFillColor(NSColor(.white).cgColor)
        ctx.setStrokeColor(NSColor(.blue).cgColor)
        ctx.setLineWidth(1 * scale)          // keep the outline 1 screen-pixel wide

        let base: CGFloat = 10               // “pixel” size you want on screen
        let size  = base * scale
        let half  = size / 2

        for element in canvas.elements where canvas.selectedIDs.contains(element.id) && element.isPrimitiveEditable {

            for handle in element.handles() {

                let radius = CGRect(
                    x: handle.position.x - half,
                    y: handle.position.y - half,
                    width: size,
                    height: size
                )

                ctx.fillEllipse(in: radius)
                ctx.strokeEllipse(in: radius)
            }
        }
    }
}
