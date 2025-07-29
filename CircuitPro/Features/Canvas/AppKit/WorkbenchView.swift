//
//  WorkbenchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit
import UniformTypeIdentifiers

final class WorkbenchView: NSView {

    // MARK: Sub-views
    weak var backgroundView: DottedBackgroundView?
    weak var sheetView: DrawingSheetView?
    weak var elementsView: ElementsView?
    weak var connectionsView: ConnectionsView?
    weak var previewView: PreviewView?
    weak var handlesView: HandlesView?
    weak var marqueeView: MarqueeView?
    weak var crosshairsView: CrosshairsView?
    weak var guideView: GuideView?

    // MARK: Model / view-state
    var elements: [CanvasElement] = [] {
        didSet {
            elementsView?.elements  = elements
            handlesView?.elements   = elements
            // Update the schematic graph with new pin positions
            syncPinPositionsToGraph()
        }
    }

    var schematicGraph: SchematicGraph = .init() {
        didSet {
            connectionsView?.schematicGraph = schematicGraph
        }
    }

    var selectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.selectedIDs = selectedIDs
            handlesView?.selectedIDs  = selectedIDs
            connectionsView?.selectedIDs  = selectedIDs
        }
    }

    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.marqueeSelectedIDs = marqueeSelectedIDs
            connectionsView?.marqueeSelectedIDs = marqueeSelectedIDs
        }
    }

    var selectedTool: AnyCanvasTool? {
        didSet {
            // We only want to notify the binding when the *type* of tool changes,
            // not when its internal state changes. Comparing by ID is perfect for this.
            if oldValue?.id != selectedTool?.id {
                // If the selectedTool is set to nil (or anything else),
                // we'll provide a valid tool to the callback, defaulting to the CursorTool.
                // This ensures the non-optional `@Binding` in CanvasView always has a value.
                onToolChange?(selectedTool ?? AnyCanvasTool(CursorTool()))
            }
            previewView?.selectedTool = selectedTool
            self.becomeFirstResponderIfAppropriate()
        }
    }

    var selectedLayer: CanvasLayer = .layer0

    var magnification: CGFloat = 1.0 {
        didSet {
            guard magnification != oldValue else { return }
            backgroundView?.magnification = magnification
            crosshairsView?.magnification = magnification
            marqueeView?.magnification = magnification
            previewView?.magnification = magnification
            handlesView?.magnification = magnification
            connectionsView?.magnification = magnification
            guideView?.magnification = magnification
        }
    }

    var isSnappingEnabled: Bool = true
    var snapGridSize: CGFloat = 10.0 {
        didSet {
            backgroundView?.unitSpacing = snapGridSize
        }
    }

    var showGuides: Bool = false {
        didSet {
            guard showGuides != oldValue else { return }

            let origin = showGuides ? CGPoint(x: bounds.midX, y: bounds.midY) : .zero

            backgroundView?.gridOrigin = origin

            if let guideView = self.guideView {
                guideView.isHidden = !showGuides
                guideView.origin = showGuides ? origin : nil
            }

            backgroundView?.needsLayout = true
        }
    }

    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet { crosshairsView?.crosshairsStyle = crosshairsStyle }
    }

    var paperSize: PaperSize = .iso(.a4)

    var sheetOrientation: PaperOrientation = .landscape

    var sheetCellValues: [String: String] = [:] {
        didSet { sheetView?.cellValues = sheetCellValues }
    }

    // MARK: Callbacks
    var onUpdate: (([CanvasElement]) -> Void)?
    var onSelectionChange: ((Set<UUID>) -> Void)?
    var onPrimitiveAdded: ((UUID, CanvasLayer) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var onToolChange: ((AnyCanvasTool) -> Void)?
    var onPinHoverChange: ((UUID?) -> Void)?
    var onComponentDropped: ((TransferableComponent, CGPoint) -> Void)?

    // MARK: Controllers
    lazy var layout = WorkbenchLayoutController(host: self)
    let hitTestService = WorkbenchHitTestService()
    lazy var input = WorkbenchInputCoordinator(workbench: self, hitTest: hitTestService)

    var isRotating: Bool { input.isRotating }

    // MARK: NSView overrides
    override var acceptsFirstResponder: Bool { true }

    // MARK: Init
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        self.registerForDraggedTypes([.transferableComponent])

        _ = layout
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        _ = layout
    }

    // MARK: Tracking & events
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseMoved(with event: NSEvent) { input.mouseMoved(event) }
    override func mouseEntered(with event: NSEvent) { input.mouseMoved(event) }
    override func mouseExited(with event: NSEvent) { input.mouseExited() }
    override func mouseDown(with event: NSEvent) { input.mouseDown(event) }
    override func mouseDragged(with event: NSEvent) { input.mouseDragged(event) }
    override func mouseUp(with event: NSEvent) { input.mouseUp(event) }

    override func rightMouseDown(with event: NSEvent) {
        input.rightMouseDown(event)
    }

    override func keyDown(with event: NSEvent) {
        if !input.keyDown(event) { super.keyDown(with: event) }
    }

    // MARK: Public helpers
    func reset() { input.reset() }

    var snapService: SnapService {
        let origin = showGuides ? CGPoint(x: bounds.midX, y: bounds.midY) : .zero
        return SnapService(
            gridSize: snapGridSize,
            isEnabled: isSnappingEnabled,
            origin: origin
        )
    }
    /// Requests that the workbench become the first responder, but only if another
    /// text input view does not already have focus. This prevents the workbench
    /// from stealing focus while the user is typing in a properties panel.
    func becomeFirstResponderIfAppropriate() {
        // Check if the current first responder is a text view (the field editor for NSTextField)
        if window?.firstResponder?.isKind(of: NSTextView.self) == true {
            // The user is typing somewhere else. Do not steal focus.
            return
        }
        
        // Otherwise, it's safe to become the first responder.
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
    }

    /// Ensures the schematic graph has vertices for every symbol pin, that their
    /// positions are up-to-date, and that vertices for deleted symbols are removed.
    private func syncPinPositionsToGraph() {
        // 1. Get all symbol IDs currently on the workbench
        let currentSymbolIDs = Set<UUID>(elements.compactMap {
            guard case .symbol(let symbol) = $0 else { return nil }
            return symbol.id
        })

        // 2. Find and remove vertices from the graph that belong to deleted symbols
        let verticesToRemove = schematicGraph.vertices.values.filter { vertex in
            if case .pin(let symbolID, _) = vertex.ownership {
                return !currentSymbolIDs.contains(symbolID)
            }
            return false
        }

        if !verticesToRemove.isEmpty {
            schematicGraph.delete(items: Set(verticesToRemove.map { $0.id }))
        }

        // 3. Update existing pins and add new ones
        for element in elements {
            guard case .symbol(let symbolElement) = element else { continue }

            let transform = CGAffineTransform(translationX: symbolElement.position.x, y: symbolElement.position.y)
                .rotated(by: symbolElement.rotation)

            for pin in symbolElement.symbol.pins {
                let worldPinPosition = pin.position.applying(transform)

                // First, check if the vertex already exists for this pin.
                if let vertexID = schematicGraph.findVertex(ownedBy: symbolElement.id, pinID: pin.id) {
                    // It exists, just move it to the correct position.
                    schematicGraph.moveVertex(id: vertexID, to: worldPinPosition)
                } else {
                    // It doesn't exist, so we must create it.
                    // This is the operation that should only happen once per pin.
                    schematicGraph.getOrCreatePinVertex(
                        at: worldPinPosition,
                        symbolID: symbolElement.id,
                        pinID: pin.id
                    )
                }
            }
        }
    }

    // old public helpers (still used by all gesture classes)
    func snap(_ point: CGPoint) -> CGPoint { snapService.snap(point) }
    func snapDelta(_ value: CGFloat) -> CGFloat { snapService.snapDelta(value) }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        input.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        input.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        input.performDragOperation(sender)
    }

}
