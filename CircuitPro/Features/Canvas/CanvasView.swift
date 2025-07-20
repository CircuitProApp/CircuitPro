import SwiftUI
import AppKit

struct CanvasView: NSViewRepresentable {
    
    // MARK: – Bindings coming from the document
    @Bindable var manager: CanvasManager
    @Bindable var schematicGraph: SchematicGraph
    @Binding var elements: [CanvasElement]
    @Binding var selectedIDs: Set<UUID>
    @Binding var selectedTool: AnyCanvasTool
    var layerBindings: CanvasLayerBindings? = nil
    
    // MARK: – Coordinator holding the App-Kit subviews
    final class Coordinator {
        let workbench: WorkbenchView
        let documentContainer: DocumentContainerView

        init() {
            self.workbench = WorkbenchView(frame: .zero)
            self.documentContainer = DocumentContainerView(workbench: workbench)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let documentContainer = context.coordinator.documentContainer

        // Scroll view scaffolding
        let scrollView = NSScrollView()
        scrollView.documentView = documentContainer
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = ZoomStep.minZoom
        scrollView.maxMagnification = ZoomStep.maxZoom
        scrollView.magnification = manager.magnification
        
        // Set a background color to create the "out of bounds" area
        scrollView.drawsBackground = false

        // Initial setup
        DispatchQueue.main.async {
            let clip = scrollView.contentView.bounds.size
            let doc = documentContainer.frame.size
            let origin = NSPoint(x: (doc.width - clip.width) * 0.5, y: (doc.height - clip.height) * 0.5)
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        
        scrollView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            let origin = scrollView.contentView.bounds.origin
            let clip = scrollView.contentView.bounds.size
            let boardHeight = context.coordinator.workbench.bounds.height
            let flippedY = boardHeight - origin.y - clip.height
            self.manager.scrollOrigin = CGPoint(x: origin.x, y: flippedY)
            self.manager.magnification = scrollView.magnification
        }
        
        return scrollView
    }

    // MARK: – Propagate state changes
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let workbench = context.coordinator.workbench
        let documentContainer = context.coordinator.documentContainer

        let paperCanvasSize = manager.paperSize.canvasSize(orientation: workbench.sheetOrientation)
        let padding: CGFloat = 1000 // 500 on each side
        let containerSize = CGSize(width: paperCanvasSize.width + padding, height: paperCanvasSize.height + padding)

        if documentContainer.frame.size != containerSize {
            documentContainer.frame.size = containerSize
        }
        
        if workbench.frame.size != paperCanvasSize {
            workbench.frame.size = paperCanvasSize
        }
        
        // Pass state to Workbench
        workbench.elements = elements
        workbench.schematicGraph  = schematicGraph
        workbench.selectedIDs = selectedIDs
        workbench.selectedTool = selectedTool
        workbench.magnification = manager.magnification
        workbench.isSnappingEnabled = manager.enableSnapping
        workbench.snapGridSize = manager.gridSpacing.rawValue * 10.0
        
        // Pass configuration to Workbench
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
        
        // Sync external zoom changes
        if scrollView.magnification != manager.magnification {
            scrollView.magnification = manager.magnification
        }
    }
}
