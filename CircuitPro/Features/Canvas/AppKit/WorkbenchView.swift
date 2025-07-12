//
//  WorkbenchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 12.07.25.
//

import AppKit

final class WorkbenchView: NSView {

    // MARK: - Views
    private weak var backgroundView: BackgroundView?
    weak var sheetView: DrawingSheetView?
    private weak var elementsView: ElementsView?
    private weak var previewView: PreviewView?
    private weak var handlesView: HandlesView?
    private weak var marqueeView: MarqueeView?
    private weak var crosshairsView: CrosshairsView?

    // MARK: - State
    var elements: [CanvasElement] = [] {
        didSet {
            elementsView?.elements = elements
            handlesView?.elements = elements
            previewView?.needsDisplay = true // Context for tools might have changed
        }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.selectedIDs = selectedIDs
            handlesView?.selectedIDs = selectedIDs
        }
    }
    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet {
            elementsView?.marqueeSelectedIDs = marqueeSelectedIDs
        }
    }
    var selectedTool: AnyCanvasTool? {
        didSet {
            previewView?.selectedTool = selectedTool
        }
    }
    var selectedLayer: CanvasLayer = .layer0 {
        didSet {
            // When layer changes, preview might need to be redrawn
            previewView?.needsDisplay = true
        }
    }
    
    var magnification: CGFloat = 1.0 {
        didSet {
            backgroundView?.magnification = magnification
            crosshairsView?.magnification = magnification
            marqueeView?.magnification = magnification
            previewView?.magnification = magnification
            handlesView?.magnification = magnification
        }
    }
    var isSnappingEnabled: Bool = true
    var snapGridSize: CGFloat = 10.0

    var backgroundStyle: CanvasBackgroundStyle = .dotted {
        didSet { backgroundView?.currentStyle = backgroundStyle }
    }
    var showAxes: Bool = true {
        didSet { backgroundView?.showAxes = showAxes }
    }
    var gridSpacing: CGFloat = 10 {
        didSet { backgroundView?.gridSpacing = gridSpacing }
    }
    var crosshairsStyle: CrosshairsStyle = .centeredCross {
        didSet { crosshairsView?.crosshairsStyle = crosshairsStyle }
    }
    var paperSize: PaperSize = .a4 {
        didSet { sheetView?.sheetSize = paperSize }
    }
    var sheetOrientation: PaperOrientation = .landscape {
        didSet { sheetView?.orientation = sheetOrientation }
    }
    var sheetCellValues: [String: String] = [:] {
        didSet { sheetView?.cellValues = sheetCellValues }
    }
    var showDrawingSheet: Bool = false {
        didSet {
            sheetView?.isHidden = !showDrawingSheet
        }
    }

    // MARK: - Callbacks
    var onUpdate: (([CanvasElement]) -> Void)?
    var onSelectionChange: ((Set<UUID>) -> Void)?
    var onPrimitiveAdded: ((UUID, CanvasLayer) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var onPinHoverChange: ((UUID?) -> Void)?

    // MARK: - Controllers
    private lazy var hitTesting = CanvasHitTestController(dataSource: self)

    // MARK: - Interaction Properties
    private var dragOrigin: CGPoint?
    private var tentativeSelection: Set<UUID>?
    private var originalPositions: [UUID: CGPoint] = [:]
    private var activeHandle: (UUID, Handle.Kind)?
    private var frozenOppositeWorld: CGPoint?
    private var didMoveSignificantly = false
    private let dragThreshold: CGFloat = 4.0
    private(set) var marqueeOrigin: CGPoint?
    private(set) var marqueeRect: CGRect? {
        didSet { marqueeView?.rect = marqueeRect }
    }
    private var isRotatingViaMouse = false
    private var rotationOrigin: CGPoint?
    var isRotating: Bool { isRotatingViaMouse }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Lifecycle
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // The order of creation determines the z-index (last is on top).
        
        let background = BackgroundView(frame: bounds)
        background.autoresizingMask = [.width, .height]
        addSubview(background)
        self.backgroundView = background
        
        let sheet = DrawingSheetView(frame: .zero) // Frame will be set by layout
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sheet)
        self.sheetView = sheet
        NSLayoutConstraint.activate([
            sheet.centerXAnchor.constraint(equalTo: centerXAnchor),
            sheet.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        let elements = ElementsView(frame: bounds)
        elements.autoresizingMask = [.width, .height]
        addSubview(elements)
        self.elementsView = elements
        
        let preview = PreviewView(frame: bounds)
        preview.autoresizingMask = [.width, .height]
        preview.workbench = self
        addSubview(preview)
        self.previewView = preview
        
        let handles = HandlesView(frame: bounds)
        handles.autoresizingMask = [.width, .height]
        addSubview(handles)
        self.handlesView = handles
        
        let marquee = MarqueeView(frame: bounds)
        marquee.autoresizingMask = [.width, .height]
        addSubview(marquee)
        self.marqueeView = marquee
        
        let crosshairs = CrosshairsView(frame: bounds)
        crosshairs.autoresizingMask = [.width, .height]
        addSubview(crosshairs)
        self.crosshairsView = crosshairs
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    // MARK: - Event Handling
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let snapped = snap(location)

        crosshairsView?.location = snapped
        onMouseMoved?(snapped)

        // Figure out whether the mouse sits on a pin
        // onPinHoverChange?(hitTesting.pin(at: location)?.id)

        if isRotating {
            updateRotation(to: location)
        }

        previewView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if isRotatingViaMouse {
            isRotatingViaMouse = false
            rotationOrigin = nil
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        if handleToolTap(at: location, event: event) { return }

        beginInteraction(at: location, event: event)

        if selectedTool?.id == "cursor", activeHandle == nil, hitTesting.hitTest(at: location) == nil {
            marqueeOrigin = location
            marqueeRect = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard let origin = dragOrigin else { return }
        updateMovementState(from: origin, to: loc)

        if let origin = marqueeOrigin, selectedTool?.id == "cursor" {
            marqueeRect = CGRect(origin: origin, size: .zero).union(CGRect(origin: loc, size: .zero))
            if let rect = marqueeRect {
                let ids = elements.filter { $0.boundingBox.intersects(rect) }.map(\CanvasElement.id)
                self.marqueeSelectedIDs = Set(ids)
            }
            return
        }

        if handleDraggingHandle(to: loc) { return }
        handleDraggingSelection(to: loc, from: origin)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            resetInteractionState()
            marqueeOrigin = nil
            marqueeRect = nil
            marqueeSelectedIDs.removeAll()
            elementsView?.needsDisplay = true
            handlesView?.needsDisplay = true
        }

        if didMoveSignificantly {
            if marqueeOrigin != nil {
                self.selectedIDs = marqueeSelectedIDs
                onSelectionChange?(self.selectedIDs)
            }
        }
        else {
            if let newSel = tentativeSelection {
                self.selectedIDs = newSel
                onSelectionChange?(self.selectedIDs)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased()

        switch key {
        case "r":
            if var tool = selectedTool, tool.id != "cursor" {
                tool.handleRotate()
                selectedTool = tool
                previewView?.needsDisplay = true
            } else if let id = selectedIDs.first,
                      let center = elements.first(where: { $0.id == id })?.primitives.first?.position {
                enterRotationMode(around: center)
            }

        case "\r", "\u{3}": // Return or Enter
            handleReturnKeyPress()
            previewView?.needsDisplay = true

        case "\u{1b}":
            if var tool = selectedTool, tool.id != "cursor" {
                tool.handleEscape()
                selectedTool = tool
                previewView?.needsDisplay = true
            }
            else {
                super.keyDown(with: event)
            }

        case String(UnicodeScalar(NSDeleteCharacter)!),
             String(UnicodeScalar(NSBackspaceCharacter)!):
            if var tool = selectedTool, tool.id != "cursor" {
                tool.handleBackspace()
                selectedTool = tool
                previewView?.needsDisplay = true
            }
            else {
                deleteSelectedElements()
            }

        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Snapping
    func snap(_ point: CGPoint) -> CGPoint {
        guard isSnappingEnabled else { return point }
        func snapValue(_ value: CGFloat) -> CGFloat {
            round(value / snapGridSize) * snapGridSize
        }
        return CGPoint(x: snapValue(point.x), y: snapValue(point.y))
    }

    func snapDelta(_ value: CGFloat) -> CGFloat {
        guard isSnappingEnabled else { return value }
        let gridSize = snapGridSize
        return round(value / gridSize) * gridSize
    }

    // MARK: - Interaction Logic (formerly CanvasInteractionController)
    func reset() {
        resetInteractionState()
    }

    func enterRotationMode(around point: CGPoint) {
        isRotatingViaMouse = true
        rotationOrigin = point
    }

    func updateRotation(to cursor: CGPoint) {
        guard isRotatingViaMouse, let origin = rotationOrigin else { return }
        var angle = atan2(cursor.y - origin.y, cursor.x - origin.x)
        if !NSEvent.modifierFlags.contains(.shift) {
            let snap: CGFloat = .pi / 12
            angle = round(angle / snap) * snap
        }
        var updated = elements
        for i in updated.indices where selectedIDs.contains(updated[i].id) {
            updated[i].setRotation(angle)
        }
        elements = updated
        onUpdate?(updated)
    }

    private func beginInteraction(at loc: CGPoint, event: NSEvent) {
        dragOrigin = loc
        didMoveSignificantly = false
        tentativeSelection = nil
        originalPositions.removeAll()
        frozenOppositeWorld = nil
        activeHandle = nil

        if tryBeginHandleInteraction(at: loc) { return }
        tryUpdateTentativeSelection(at: loc, with: event)
    }

    private func tryBeginHandleInteraction(at loc: CGPoint) -> Bool {
        guard selectedIDs.count == 1 else { return false }
        let tolerance = 8.0 / magnification
        for element in elements where selectedIDs.contains(element.id) && element.isPrimitiveEditable {
            for handle in element.handles() where hypot(loc.x - handle.position.x, loc.y - handle.position.y) < tolerance {
                activeHandle = (element.id, handle.kind)
                if let oppositeKind = handle.kind.opposite, let opposite = element.handles().first(where: { $0.kind == oppositeKind }) {
                    frozenOppositeWorld = opposite.position
                }
                return true
            }
        }
        return false
    }

    private func tryUpdateTentativeSelection(at loc: CGPoint, with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let hitID = hitTesting.hitTest(at: loc)

        guard let id = hitID else {
            if !shift {
                tentativeSelection = []
            }
            return
        }

        let wasSelected = selectedIDs.contains(id)
        if wasSelected {
            tentativeSelection = selectedIDs.subtracting([id])
            if !shift {
                for element in elements where selectedIDs.contains(element.id) {
                    if case .connection = element { continue }
                    let position: CGPoint
                    if case .symbol(let symbol) = element {
                        position = symbol.instance.position
                    } else if let primitive = element.primitives.first {
                        position = primitive.position
                    } else {
                        continue
                    }
                    originalPositions[element.id] = position
                }
            }
        }
        else {
            tentativeSelection = shift ? selectedIDs.union([id]) : [id]
        }
        if let element = elements.first(where: { $0.id == id }) {
            if case .connection = element { return }
            let position: CGPoint
            if case .symbol(let symbol) = element {
                position = symbol.instance.position
            } else if let primitive = element.primitives.first {
                position = primitive.position
            }
            else {
                return
            }
            originalPositions[id] = position
        }
    }

    private func updateMovementState(from origin: CGPoint, to loc: CGPoint) {
        if !didMoveSignificantly && hypot(loc.x - origin.x, loc.y - origin.y) >= dragThreshold {
            didMoveSignificantly = true
        }
    }

    private func handleDraggingHandle(to loc: CGPoint) -> Bool {
        guard let (id, kind) = activeHandle else { return false }
        var updated = elements
        let snapped = snap(loc)
        for i in updated.indices where updated[i].id == id {
            updated[i].updateHandle(kind, to: snapped, opposite: frozenOppositeWorld)
            elements = updated
            onUpdate?(updated)
            return true
        }
        return false
    }

    private func handleDraggingSelection(to loc: CGPoint, from origin: CGPoint) {
        guard !originalPositions.isEmpty else { return }
        let delta = CGPoint(x: snapDelta(loc.x - origin.x), y: snapDelta(loc.y - origin.y))
        var updated = elements
        for i in updated.indices {
            guard let orig = originalPositions[updated[i].id] else { continue }
            if case .connection = updated[i] { continue }
            updated[i].moveTo(originalPosition: orig, offset: delta)
        }
        elements = updated
        onUpdate?(updated)
    }

    private func resetInteractionState() {
        dragOrigin = nil
        originalPositions.removeAll()
        didMoveSignificantly = false
        activeHandle = nil
        frozenOppositeWorld = nil
    }

    private func handleToolTap(at loc: CGPoint, event: NSEvent) -> Bool {
        guard var tool = selectedTool, tool.id != "cursor" else {
            return false
        }

        let snapped = snap(loc)
        var context = CanvasToolContext(
            existingPinCount: elements.reduce(0) { $1.isPin ? $0 + 1 : $0 },
            existingPadCount: elements.reduce(0) { $1.isPad ? $0 + 1 : $0 },
            selectedLayer: selectedLayer,
            magnification: magnification
        )

        if tool.id == "connection" {
            context.hitTarget = hitTesting.hitTestForConnection(at: snapped)
        }
        context.clickCount = event.clickCount

        if let element = tool.handleTap(at: snapped, context: context) {
            elements.append(element)
            if case .primitive(let prim) = element {
                onPrimitiveAdded?(prim.id, context.selectedLayer)
            }
            onUpdate?(elements)
        }

        selectedTool = tool
        return true
    }

    func handleReturnKeyPress() {
        guard var tool = selectedTool, tool.id == "connection" else { return }
        if let newElement = tool.handleReturn() {
            elements.append(newElement)
            onUpdate?(elements)
        }
        selectedTool = tool
    }

    private func deleteSelectedElements() {
        guard !selectedIDs.isEmpty else { return }
        elements.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        onSelectionChange?(selectedIDs)
        onUpdate?(elements)
    }
}

extension WorkbenchView: CanvasHitTestControllerDataSource {
    func elementsForHitTesting() -> [CanvasElement] {
        return elements
    }

    func magnificationForHitTesting() -> CGFloat {
        return magnification
    }
}
