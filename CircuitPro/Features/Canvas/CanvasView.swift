import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {

    // MARK: – Bindings coming from the document
    @Bindable var manager: CanvasManager
    @Binding var elements: [CanvasElement]
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool
    var layerBindings: CanvasLayerBindings? = nil

    // MARK: – Coordinator holding the App-Kit subviews
    final class Coordinator {
        let workbench: WorkbenchView
        
        init() {
            let boardSize: CGFloat = 5_000
            let boardRect = NSRect(x: 0, y: 0, width: boardSize, height: boardSize)
            self.workbench = WorkbenchView(frame: boardRect)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let workbench = context.coordinator.workbench

        // Scroll view scaffolding
        let scrollView = NSScrollView()
        scrollView.documentView = workbench
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = ZoomStep.minZoom
        scrollView.maxMagnification = ZoomStep.maxZoom
        scrollView.magnification = manager.magnification

        // Initial setup
        if manager.showDrawingSheet {
            centerScrollView(on: workbench.sheetView, in: scrollView)
        } else {
            centerScrollView(scrollView, container: workbench)
        }

        scrollView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            let origin = scrollView.contentView.bounds.origin
            let clip = scrollView.contentView.bounds.size
            let boardHeight = workbench.bounds.height
            let flippedY = boardHeight - origin.y - clip.height
            self.manager.scrollOrigin = CGPoint(x: origin.x, y: flippedY)
            self.manager.magnification = scrollView.magnification
        }

        return scrollView
    }

    // MARK: – Propagate state changes
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let workbench = context.coordinator.workbench

        // Pass state to Workbench
        workbench.elements = elements
        workbench.selectedIDs = selectedIDs
        workbench.selectedTool = selectedTool
        workbench.magnification = manager.magnification
        workbench.isSnappingEnabled = manager.enableSnapping
        workbench.snapGridSize = manager.gridSpacing.rawValue * 10.0
        
        // Pass configuration to Workbench
        workbench.backgroundStyle = manager.backgroundStyle
        workbench.showAxes = manager.enableAxesBackground
        workbench.gridSpacing = manager.gridSpacing.rawValue * 10.0
        workbench.crosshairsStyle = manager.crosshairsStyle
        workbench.paperSize = manager.paperSize
        var cellValues = workbench.sheetCellValues
        cellValues["Size"] = manager.paperSize.name.uppercased()
        workbench.sheetCellValues = cellValues
        
        // Callbacks
        workbench.onUpdate = { self.elements = $0 }
        workbench.onSelectionChange = { self.selectedIDs = $0 }
        workbench.onMouseMoved = { position in self.manager.mouseLocation = position }
        workbench.onPinHoverChange = { id in
            if let id = id { print("Hovering pin \(id)") }
        }

        if let layers = layerBindings {
            workbench.selectedLayer = layers.selectedLayer.wrappedValue ?? .layer0
            let assignments = layers.layerAssignments
            workbench.onPrimitiveAdded = { id, layer in
                assignments.wrappedValue[id] = layer
            }
        } else {
            workbench.selectedLayer = .layer0
            workbench.onPrimitiveAdded = nil
        }

        // Update sheet visibility and centering
        if workbench.showDrawingSheet != manager.showDrawingSheet {
            workbench.showDrawingSheet = manager.showDrawingSheet
            if manager.showDrawingSheet {
                centerScrollView(on: workbench.sheetView, in: scrollView)
            } else {
                centerScrollView(scrollView, container: workbench)
            }
        }
        
        // Sync external zoom changes
        if scrollView.magnification != manager.magnification {
            scrollView.magnification = manager.magnification
        }
    }

    // MARK: – Helpers
    private func centerScrollView(_ scrollView: NSScrollView, container: NSView) {
        DispatchQueue.main.async {
            let clip = scrollView.contentView.bounds.size
            let doc = container.frame.size
            let origin = NSPoint(x: (doc.width - clip.width) * 0.5, y: (doc.height - clip.height) * 0.5)
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func centerScrollView(on sheet: NSView?, in scrollView: NSScrollView) {
        guard let sheet = sheet else { return }
        DispatchQueue.main.async {
            let clipSize = scrollView.contentView.bounds.size
            let sheetFrame = sheet.frame
            let sheetCenter = NSPoint(x: sheetFrame.midX, y: sheetFrame.midY)
            var origin = NSPoint(x: sheetCenter.x - clipSize.width * 0.5, y: sheetCenter.y - clipSize.height * 0.5)
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
