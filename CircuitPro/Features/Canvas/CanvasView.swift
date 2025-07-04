import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: – Bindings coming from the document
    @Bindable var manager: CanvasManager
    @Binding var elements:          [CanvasElement]
    @Binding var selectedIDs:       Set<UUID>
    @Binding var selectedTool:      AnyCanvasTool
    @Binding var selectedLayer:     LayerKind?
    @Binding var layerAssignments:  [UUID: LayerKind]

    // MARK: – Coordinator holding the App-Kit subviews
    final class Coordinator {
        let background = BackgroundView()
        let sheet      = DrawingSheetView()            // ← NEW
        let canvas     = CoreGraphicsCanvasView()
        let crosshairs = CrosshairsView()
        let marquee    = MarqueeView()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let boardSize: CGFloat = 5_000
        let boardRect = NSRect(x: 0, y: 0, width: boardSize, height: boardSize)

        let c = context.coordinator

        //----------------------------------------------------------------------
        // 1. Paper dimensions in internal units
        //----------------------------------------------------------------------
        let paperSize = manager.paperSize
            .canvasSize(scale: 10, orientation: .landscape)

        //----------------------------------------------------------------------
        // 2. Frame assignments
        //----------------------------------------------------------------------
        c.background.frame  = boardRect
        c.canvas.frame      = boardRect
        c.crosshairs.frame  = boardRect
        c.marquee.frame     = boardRect

        // MARK: – choose where the sheet’s *top-left* must be
        let desiredTopLeft = NSPoint(x: 2_500, y: 2_500)

        // convert that into a bottom-left origin
        let sheetOrigin = NSPoint(
            x: desiredTopLeft.x,
            y: desiredTopLeft.y - paperSize.height
        )

        // finally set the frame
        c.sheet.frame = NSRect(origin: sheetOrigin, size: paperSize)
        c.sheet.orientation = .landscape
        c.sheet.autoresizingMask = []

        [c.background, c.canvas, c.crosshairs, c.marquee].forEach {
            $0.autoresizingMask = [.width, .height]
        }

        c.background.currentStyle = manager.backgroundStyle

        c.canvas.crosshairsView  = c.crosshairs
        c.canvas.marqueeView     = c.marquee
        c.canvas.elements        = elements
        c.canvas.selectedIDs     = selectedIDs
        c.canvas.selectedTool    = selectedTool
        c.canvas.magnification   = manager.magnification
        c.canvas.onUpdate        = { self.elements = $0 }
        c.canvas.onSelectionChange = { self.selectedIDs = $0 }

        // Drawing sheet initialization
        c.sheet.sheetSize    = .a4
        c.sheet.cellValues   = [
            "Title":   "Test Layout/Sheet",
            "Project": "ProjectName",
            "Units":   "mm",
            "Size":    PaperSize.a4.name.uppercased()
        ]

        // Z-stack container
        let container = NSView(frame: boardRect)
        container.wantsLayer = true
        container.addSubview(c.background)

        // Scroll view scaffolding
        let scrollView = NSScrollView()
        scrollView.documentView            = container
        scrollView.hasHorizontalScroller   = true
        scrollView.hasVerticalScroller     = true
        scrollView.allowsMagnification     = true
        scrollView.minMagnification        = ZoomStep.minZoom
        scrollView.maxMagnification        = ZoomStep.maxZoom
        scrollView.magnification           = manager.magnification

        // Conditional display of sheet and scrolling
        if manager.showDrawingSheet {
            container.addSubview(c.sheet, positioned: .above, relativeTo: c.background)
            centerScrollView(on: c.sheet, in: scrollView)
        } else {
            centerScrollView(scrollView, container: container)
        }

        container.addSubview(c.canvas,     positioned: .above, relativeTo: c.sheet)
        container.addSubview(c.crosshairs, positioned: .above, relativeTo: c.canvas)
        container.addSubview(c.marquee,    positioned: .above, relativeTo: c.canvas)

        scrollView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            let origin      = scrollView.contentView.bounds.origin        // bottom-left
            let clip        = scrollView.contentView.bounds.size          // visible size
            let boardHeight = container.bounds.height                     // = 5 000

            // convert Y so that 0,0 becomes board *top-left* and Y grows downward
            let flippedY = boardHeight - origin.y - clip.height

            self.manager.scrollOrigin = CGPoint(x: origin.x, y: flippedY) // top-left, Y-down
            self.manager.magnification = scrollView.magnification
        }

        return scrollView
    }

    // MARK: – Propagate state changes
    func updateNSView(_ scrollView: NSScrollView, context: Context) {

        let c = context.coordinator

        // Canvas
        c.canvas.elements          = elements
        c.canvas.selectedIDs       = selectedIDs
        c.canvas.selectedTool      = selectedTool
        c.canvas.magnification     = manager.magnification
        c.canvas.isSnappingEnabled = manager.enableSnapping
        c.canvas.snapGridSize      = manager.gridSpacing.rawValue * 10.0
        c.canvas.selectedLayer     = selectedLayer ?? .copper
        c.canvas.onPrimitiveAdded  = { id, layer in self.layerAssignments[id] = layer }
        c.canvas.onMouseMoved      = { p in self.manager.mouseLocation = p }

        c.canvas.onPinHoverChange = { id in
            if let id = id {
                print("Hovering pin \(id)")
            }
        }

        // Background
        if c.background.currentStyle != manager.backgroundStyle {
            c.background.currentStyle = manager.backgroundStyle
        }
        c.background.showAxes      = manager.enableAxesBackground
        c.background.magnification = manager.magnification
        c.background.gridSpacing   = manager.gridSpacing.rawValue * 10.0

        // Cross-hairs & marquee
        c.crosshairs.magnification = manager.magnification
        c.crosshairs.crosshairsStyle = manager.crosshairsStyle
        c.marquee.magnification    = manager.magnification

        // Drawing sheet
        c.sheet.sheetSize   = manager.paperSize
        c.sheet.orientation = .landscape
        c.sheet.cellValues["Size"] = manager.paperSize.name.uppercased()

        let newPaperSize = manager.paperSize
            .canvasSize(scale: 10, orientation: .landscape)
        if c.sheet.frame.size != newPaperSize {
            c.sheet.frame.size = newPaperSize
        }

        // Update view for drawing sheet visibility
        if manager.showDrawingSheet {
            if !c.sheet.isDescendant(of: scrollView.documentView!) {
                scrollView.documentView?.addSubview(c.sheet, positioned: .above, relativeTo: c.background)
                centerScrollView(on: c.sheet, in: scrollView)
            }
        } else {
            if c.sheet.isDescendant(of: scrollView.documentView!) {
                c.sheet.removeFromSuperview()
                centerScrollView(scrollView, container: scrollView.documentView!)
            }
        }

        // Sync external zoom changes
        if scrollView.magnification != manager.magnification {
            scrollView.magnification = manager.magnification
        }
    }

    // MARK: – Helpers
    private func colorForScheme(_ scheme: ColorScheme) -> NSColor {
        scheme == .dark ? .white : .black
    }

    private func centerScrollView(_ scrollView: NSScrollView, container: NSView) {
        DispatchQueue.main.async {
            let clip = scrollView.contentView.bounds.size
            let doc  = container.frame.size
            let origin = NSPoint(
                x: (doc.width  - clip.width)  * 0.5,
                y: (doc.height - clip.height) * 0.5
            )
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    /// Centres the scroll view on the drawing sheet instead of on the board.
    private func centerScrollView(on sheet: NSView,
                                  in scrollView: NSScrollView) {
        DispatchQueue.main.async {
            let clipSize    = scrollView.contentView.bounds.size
            let sheetFrame  = sheet.frame                 // in container coords

            // Mid-point of the sheet.
            let sheetCenter = NSPoint(x: sheetFrame.midX,
                                      y: sheetFrame.midY)

            // Clip origin that would place the sheet centre at the clip centre.
            var origin = NSPoint(x: sheetCenter.x - clipSize.width  * 0.5,
                                 y: sheetCenter.y - clipSize.height * 0.5)

            // Clamp so we never scroll beyond the container’s bounds.
            if let container = scrollView.documentView {
                let maxX = container.frame.maxX - clipSize.width
                let maxY = container.frame.maxY - clipSize.height
                origin.x = max(0, min(origin.x, maxX))
                origin.y = max(0, min(origin.y, maxY))
            }

            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
