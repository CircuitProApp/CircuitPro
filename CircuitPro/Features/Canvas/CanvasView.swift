import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: – Bindings coming from the document
    @Bindable var manager: CanvasManager
    @Binding var elements: [CanvasElement]
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool
    @Binding var selectedLayer: LayerKind?
    @Binding var layerAssignments: [UUID: LayerKind]

    // MARK: – Coordinator holding the App-Kit subviews
    final class Coordinator {
        let background = BackgroundView()
        let sheet      = DrawingSheetView()            // ← NEW
        let canvas     = CoreGraphicsCanvasView()
        let crosshairs = CrosshairsView()
        let marquee    = MarqueeView()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // swiftlint:disable:next function_body_length
    func makeNSView(context: Context) -> NSScrollView {
        let boardSize: CGFloat = 5_000
        let boardRect = NSRect(x: 0, y: 0, width: boardSize, height: boardSize)

        let coordinator = context.coordinator

        // 1. Paper dimensions in internal units
        let paperSize = manager.paperSize.canvasSize(scale: 10, orientation: .landscape)

        // 2. Frame assignments
        coordinator.background.frame  = boardRect
        coordinator.canvas.frame      = boardRect
        coordinator.crosshairs.frame  = boardRect
        coordinator.marquee.frame     = boardRect

        // MARK: – choose where the sheet’s *top-left* must be
        let desiredTopLeft = NSPoint(x: 2_500, y: 2_500)

        // convert that into a bottom-left origin
        let sheetOrigin = NSPoint(
            x: desiredTopLeft.x,
            y: desiredTopLeft.y - paperSize.height
        )

        // finally set the frame
        coordinator.sheet.frame = NSRect(origin: sheetOrigin, size: paperSize)
        coordinator.sheet.orientation = .landscape
        coordinator.sheet.autoresizingMask = []

        [coordinator.background, coordinator.canvas, coordinator.crosshairs, coordinator.marquee].forEach {
            $0.autoresizingMask = [.width, .height]
        }

        coordinator.background.currentStyle = manager.backgroundStyle

        coordinator.canvas.crosshairsView  = coordinator.crosshairs
        coordinator.canvas.marqueeView = coordinator.marquee
        coordinator.canvas.elements = elements
        coordinator.canvas.selectedIDs = selectedIDs
        coordinator.canvas.selectedTool = selectedTool
        coordinator.canvas.magnification = manager.magnification
        coordinator.canvas.onUpdate = { self.elements = $0 }
        coordinator.canvas.onSelectionChange = { self.selectedIDs = $0 }

        // Drawing sheet initialization
        coordinator.sheet.sheetSize    = .a4
        coordinator.sheet.cellValues   = [
            "Title": "Test Layout/Sheet",
            "Project": "ProjectName",
            "Units": "mm",
            "Size": PaperSize.a4.name.uppercased()
        ]

        // Z-stack container
        let container = NSView(frame: boardRect)
        container.wantsLayer = true
        container.addSubview(coordinator.background)

        // Scroll view scaffolding
        let scrollView = NSScrollView()
        scrollView.documentView = container
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = ZoomStep.minZoom
        scrollView.maxMagnification = ZoomStep.maxZoom
        scrollView.magnification = manager.magnification

        // Conditional display of sheet and scrolling
        if manager.showDrawingSheet {
            container.addSubview(coordinator.sheet, positioned: .above, relativeTo: coordinator.background)
            centerScrollView(on: coordinator.sheet, in: scrollView)
        } else {
            centerScrollView(scrollView, container: container)
        }

        container.addSubview(coordinator.canvas, positioned: .above, relativeTo: coordinator.sheet)
        container.addSubview(coordinator.crosshairs, positioned: .above, relativeTo: coordinator.canvas)
        container.addSubview(coordinator.marquee, positioned: .above, relativeTo: coordinator.canvas)

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

        let coordinator = context.coordinator

        // Canvas
        coordinator.canvas.elements = elements
        coordinator.canvas.selectedIDs = selectedIDs
        coordinator.canvas.selectedTool = selectedTool
        coordinator.canvas.magnification = manager.magnification
        coordinator.canvas.isSnappingEnabled = manager.enableSnapping
        coordinator.canvas.snapGridSize = manager.gridSpacing.rawValue * 10.0
        coordinator.canvas.selectedLayer = selectedLayer ?? .copper
        coordinator.canvas.onPrimitiveAdded = { id, layer in self.layerAssignments[id] = layer }
        coordinator.canvas.onMouseMoved = { position in self.manager.mouseLocation = position }

        coordinator.canvas.onPinHoverChange = { id in
            if let id = id {
                print("Hovering pin \(id)")
            }
        }

        // Background
        if coordinator.background.currentStyle != manager.backgroundStyle {
            coordinator.background.currentStyle = manager.backgroundStyle
        }
        coordinator.background.showAxes = manager.enableAxesBackground
        coordinator.background.magnification = manager.magnification
        coordinator.background.gridSpacing = manager.gridSpacing.rawValue * 10.0

        // Cross-hairs & marquee
        coordinator.crosshairs.magnification = manager.magnification
        coordinator.crosshairs.crosshairsStyle = manager.crosshairsStyle
        coordinator.marquee.magnification = manager.magnification

        // Drawing sheet
        coordinator.sheet.sheetSize = manager.paperSize
        coordinator.sheet.orientation = .landscape
        coordinator.sheet.cellValues["Size"] = manager.paperSize.name.uppercased()

        let newPaperSize = manager.paperSize.canvasSize(scale: 10, orientation: .landscape)

        if coordinator.sheet.frame.size != newPaperSize {
            coordinator.sheet.frame.size = newPaperSize
        }

        // Update view for drawing sheet visibility
        if manager.showDrawingSheet {
            if !coordinator.sheet.isDescendant(of: scrollView.documentView!) {
                scrollView.documentView?.addSubview(
                    coordinator.sheet,
                    positioned: .above,
                    relativeTo: coordinator.background
                )
                centerScrollView(on: coordinator.sheet, in: scrollView)
            }
        } else {
            if coordinator.sheet.isDescendant(of: scrollView.documentView!) {
                coordinator.sheet.removeFromSuperview()
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
    private func centerScrollView(on sheet: NSView, in scrollView: NSScrollView) {
        DispatchQueue.main.async {
            let clipSize    = scrollView.contentView.bounds.size
            let sheetFrame  = sheet.frame                 // in container coords

            // Mid-point of the sheet.
            let sheetCenter = NSPoint(x: sheetFrame.midX, y: sheetFrame.midY)

            // Clip origin that would place the sheet centre at the clip centre.
            var origin = NSPoint(x: sheetCenter.x - clipSize.width  * 0.5, y: sheetCenter.y - clipSize.height * 0.5)

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
