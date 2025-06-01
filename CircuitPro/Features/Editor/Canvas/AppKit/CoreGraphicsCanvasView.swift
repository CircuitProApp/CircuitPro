import AppKit

final class CoreGraphicsCanvasView: NSView {

    // MARK: Public API
    var elements: [CanvasElement] = [] {
        didSet { needsDisplay = true }
    }

    var selectedIDs: Set<UUID> = [] {
        didSet {
            needsDisplay = true
            if selectedIDs != oldValue { onSelectionChange?(selectedIDs) }
        }
    }

    var magnification: CGFloat = 1.0
    var isSnappingEnabled: Bool = true
    var snapGridSize: CGFloat = 10.0

    var onUpdate: (([CanvasElement]) -> Void)?
    var onSelectionChange: ((Set<UUID>) -> Void)?
    var onPrimitiveAdded: ((UUID, LayerKind) -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?


    // MARK: Private Controllers
    private lazy var interaction = CanvasInteractionController(canvas: self)
    private lazy var drawing = CanvasDrawingController(canvas: self)
    private lazy var hitTesting = CanvasHitTestController(canvas: self)

    var selectedTool: AnyCanvasTool?
    var selectedLayer: LayerKind = .copper

    override var isFlipped: Bool { true }

    weak var crosshairsView: CrosshairsView?

    override init(frame: NSRect) {
        super.init(frame: .init(origin: .zero, size: .init(width: 5000, height: 5000)))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        hitTesting.updateRects()
        drawing.draw(in: ctx, dirtyRect: dirtyRect)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        crosshairsView?.location = snap(location)
        
        onMouseMoved?(snap(location))

        if interaction.isRotating {
            interaction.updateRotation(to: location)
        }

        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        interaction.mouseDown(at: convert(event.locationInWindow, from: nil), event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        interaction.mouseDragged(to: convert(event.locationInWindow, from: nil), event: event)
    }

    override func mouseUp(with event: NSEvent) {
        interaction.mouseUp(at: convert(event.locationInWindow, from: nil), event: event)
    }

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased()

        switch key {
        case "r":
            if let id = selectedIDs.first,
               let center = elements.first(where: { $0.id == id })?.primitives.first?.position {
                interaction.enterRotationMode(around: center)
            }

        case String(UnicodeScalar(NSDeleteCharacter)!),
             String(UnicodeScalar(NSBackspaceCharacter)!):
            deleteSelectedElements()

        default:
            super.keyDown(with: event)
        }
    }

    private func deleteSelectedElements() {
        guard !selectedIDs.isEmpty else { return }

        elements.removeAll { selectedIDs.contains($0.id) }

        selectedIDs.removeAll()
        onSelectionChange?(selectedIDs)
        onUpdate?(elements)

        needsDisplay = true
    }
    // MARK: Internal Accessors for Controllers
    var hitRects: CanvasHitTestController { hitTesting }
    var marqueeRect: CGRect? { interaction.marqueeRect }
}
