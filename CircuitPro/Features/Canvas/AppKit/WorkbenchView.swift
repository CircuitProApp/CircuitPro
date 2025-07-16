//
//  WorkbenchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class WorkbenchView: NSView {

    // MARK: Sub-views
    weak var sheetView:      DrawingSheetView?
    weak var elementsView:   ElementsView?
    weak var previewView:    PreviewView?
    weak var handlesView:    HandlesView?
    weak var marqueeView:    MarqueeView?
    weak var crosshairsView: CrosshairsView?

    // MARK: Model / view-state
    var elements: [CanvasElement] = [] {
        didSet {
            elementsView?.elements  = elements
            handlesView?.elements   = elements
            previewView?.needsDisplay = true
        }
    }

    var selectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.selectedIDs = selectedIDs
            handlesView?.selectedIDs  = selectedIDs
        }
    }

    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet { elementsView?.marqueeSelectedIDs = marqueeSelectedIDs }
    }

    var selectedTool: AnyCanvasTool? {
        didSet { previewView?.selectedTool = selectedTool }
    }

    var selectedLayer: CanvasLayer = .layer0 {
        didSet { previewView?.needsDisplay = true }
    }

    var magnification: CGFloat = 1.0 {
        didSet {
            guard magnification != oldValue else { return }
            crosshairsView?.magnification = magnification
            marqueeView?.magnification    = magnification
            previewView?.magnification    = magnification
            handlesView?.magnification    = magnification
        }
    }

    var isSnappingEnabled: Bool = true
    var snapGridSize:      CGFloat = 10.0

    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet { crosshairsView?.crosshairsStyle = crosshairsStyle }
    }

    var paperSize: PaperSize = .a4 {
        didSet {
            sheetView?.sheetSize = paperSize
            layout.refreshSheetSize()
        }
    }

    var sheetOrientation: PaperOrientation = .landscape {
        didSet {
            sheetView?.orientation = sheetOrientation
            layout.refreshSheetSize()
        }
    }

    var sheetCellValues: [String:String] = [:] {
        didSet { sheetView?.cellValues = sheetCellValues }
    }

    var showDrawingSheet: Bool = false {
        didSet { sheetView?.isHidden = !showDrawingSheet }
    }

    // MARK: Callbacks
    var onUpdate:          (([CanvasElement]) -> Void)?
    var onSelectionChange: ((Set<UUID>)      -> Void)?
    var onPrimitiveAdded:  ((UUID, CanvasLayer) -> Void)?
    var onMouseMoved:      ((CGPoint)        -> Void)?
    var onPinHoverChange:  ((UUID?)          -> Void)?

    // MARK: Controllers
    lazy var layout     = WorkbenchLayoutController(host: self)
    let  hitTestService    = WorkbenchHitTestService()
    lazy var input      = WorkbenchInputCoordinator(workbench: self, hitTest: hitTestService)

    var isRotating: Bool { input.isRotating }

    // MARK: NSView overrides
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Init
    override init(frame: NSRect) {
        super.init(frame: frame)
        _ = layout
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
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
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseMoved(with e: NSEvent)   { input.mouseMoved(e) }
    override func mouseDown(with e: NSEvent)    { input.mouseDown(e) }
    override func mouseDragged(with e: NSEvent) { input.mouseDragged(e) }
    override func mouseUp(with e: NSEvent)      { input.mouseUp(e) }

    override func keyDown(with e: NSEvent) {
        if !input.keyDown(e) { super.keyDown(with: e) }
    }

    // MARK: Public helpers
    func reset() { input.reset() }

    var snapService: SnapService {
        SnapService(gridSize: snapGridSize,
                    isEnabled: isSnappingEnabled)
    }

    // old public helpers (still used by all gesture classes)
    func snap(_ p: CGPoint) -> CGPoint    { snapService.snap(p) }
    func snapDelta(_ v: CGFloat) -> CGFloat { snapService.snapDelta(v) }
}
