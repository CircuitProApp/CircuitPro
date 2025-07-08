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

    private(set) var hoveredPinID: UUID? {
        didSet {
            if hoveredPinID != oldValue {
                // let anyone interested know that the hover target changed
                onPinHoverChange?(hoveredPinID)
            }
        }
    }
    var onPinHoverChange: ((UUID?) -> Void)?

    // MARK: Private Controllers
    private lazy var interaction = CanvasInteractionController(canvas: self)
    private lazy var drawing = CanvasDrawingController(canvas: self)
    private lazy var hitTesting = CanvasHitTestController(canvas: self)

    var selectedTool: AnyCanvasTool?
    var selectedLayer: LayerKind = .copper

    override var isFlipped: Bool { true }

    weak var crosshairsView: CrosshairsView?
    weak var marqueeView: MarqueeView?

    override init(frame: NSRect) {
        super.init(frame: .init(origin: .zero, size: .init(width: 5000, height: 5000)))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawing.draw(in: ctx, dirtyRect: dirtyRect)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let snapped  = snap(location)

        crosshairsView?.location = snapped
        onMouseMoved?(snapped)

        // NEW ─ figure out whether the mouse sits on a pin
        hoveredPinID = hitRects.pin(at: location)?.id

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
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

        var out: [CanvasElement] = []

        for element in elements {

            switch element {

            // 1 ─ connections: remove only the selected segments
            case .connection(let conn):
                // If the entire connection is selected, drop it completely.
                guard !selectedIDs.contains(conn.id) else { continue }

                let edgeIDs = Set(conn.net.edges.compactMap { selectedIDs.contains($0.id) ? $0.id : nil })
                if edgeIDs.isEmpty {
                    out.append(element)
                } else {
                    let nets = conn.net.deletingEdges(withIDs: edgeIDs)
                    out.append(contentsOf: nets.map { .connection(ConnectionElement(id: $0.id, net: $0)) })
                }

            // 2 ─ anything else: drop the whole object when its id is selected
            default:
                if !selectedIDs.contains(element.id) { out.append(element) }
            }
        }

        elements = out
        selectedIDs.removeAll()
        onSelectionChange?(selectedIDs)
        onUpdate?(elements)
        needsDisplay = true
    }

    // MARK: Internal Accessors for Controllers
    var hitRects: CanvasHitTestController { hitTesting }
    var marqueeRect: CGRect? { interaction.marqueeRect }
}
