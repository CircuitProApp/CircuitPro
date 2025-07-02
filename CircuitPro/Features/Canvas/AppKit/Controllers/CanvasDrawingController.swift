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
    // MARK: - 1 elements
    private func drawElements(in ctx: CGContext) {

        for element in canvas.elements {

            switch element {
            case .connection(let conn):
                // segment-level highlight
                drawConnection(conn,
                               in: ctx,
                               selectedIDs: canvas.selectedIDs)

            default:
                // unchanged for every other kind
                let sel = canvas.selectedIDs.contains(element.id)
                element.drawable.draw(in: ctx, selected: sel)
            }
        }
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

// CanvasDrawingController.swift
// ONLY the part that draws connections is new

private extension CanvasDrawingController {

    func drawConnection(_ conn: ConnectionElement,
                        in ctx: CGContext,
                        selectedIDs: Set<UUID>) {

        for prim in conn.primitives {

            // a single stroke is selected when its own id OR the whole
            // connection’s id lives in the selection set
            let thisIsSelected = selectedIDs.contains(prim.id) ||
                                 selectedIDs.contains(conn.id)

            ctx.saveGState()

            if thisIsSelected {
                ctx.setStrokeColor(NSColor(.blue.opacity(0.3)).cgColor)
                ctx.setLineWidth(4)
                ctx.setLineCap(.round)
                ctx.addPath(prim.makePath())
                ctx.strokePath()
            }

            prim.drawBody(in: ctx)        // normal appearance
            ctx.restoreGState()
        }
    }
}
