import AppKit

final class ElementsView: NSView {

    // MARK: - Data
    // We update the observers to call a single, unified update function.
    var elements: [CanvasElement] = [] {
        didSet { redrawLayers() }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet { redrawLayers() }
    }
    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet { redrawLayers() }
    }
    
    var magnification: CGFloat = 1.0

    // MARK: – Layer Storage (Unchanged)
    private var elementBodyLayers: [UUID: [CAShapeLayer]] = [:]
    private var selectionHaloLayers: [UUID: CAShapeLayer] = [:]

    // MARK: - Init (Unchanged)
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
    }

    // MARK: - View Configuration (Unchanged)
    override var isOpaque: Bool { false }
    override func hitTest(_: NSPoint) -> NSView? { nil }

    // MARK: - Unified Layer Management (NEW & REFACTORED)
    
    /// This is the new, single entry point for all visual updates.
    /// It's called whenever elements or selections change.
    private func redrawLayers() {
        CATransaction.begin()
        // Disabling animations makes the update feel instantaneous.
        CATransaction.setDisableActions(true)

        // 1. Clean Slate: Remove all existing layers.
        // This is simpler and less error-prone than complex diffing.
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        elementBodyLayers.removeAll()
        selectionHaloLayers.removeAll()
        
        let allSelectedIDs = selectedIDs.union(marqueeSelectedIDs)

        // 2. Re-create all layers from the current state.
        for element in elements {
            guard let hostLayer = self.layer else { continue }
            
            // 2.1. Re-create the body layers for the element.
            let bodyParams = element.drawable.makeBodyParameters()
            let newBodyLayers = bodyParams.map { createLayer(from: $0) }
            elementBodyLayers[element.id] = newBodyLayers
            newBodyLayers.forEach { hostLayer.addSublayer($0) }
            
            // 2.2. Re-create the halo layer for the element using our new context-aware method.
            // This is the core of the new logic. We pass the full selection context down.
            // The element itself decides IF and WHAT to halo.
            if let haloParams = element.drawable.makeHaloParameters(selectedIDs: allSelectedIDs) {
                
                // The returned path might be for the whole element OR just a sub-part.
                let haloLayer = createLayer(from: haloParams)
                selectionHaloLayers[element.id] = haloLayer
                
                // Insert the halo behind the body.
                if let firstBodyLayer = newBodyLayers.first {
                    hostLayer.insertSublayer(haloLayer, below: firstBodyLayer)
                } else {
                    hostLayer.addSublayer(haloLayer)
                }
            }
        }
        CATransaction.commit()
    }

    // MARK: - Layer Creation (Unchanged)
    // This helper remains the canonical way to create any layer from parameters.
    private func createLayer(from p: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = p.path
        layer.fillColor = p.fillColor
        layer.strokeColor = p.strokeColor
        layer.lineWidth = p.lineWidth
        layer.lineCap = p.lineCap
        layer.lineJoin = p.lineJoin
        layer.lineDashPattern = p.lineDashPattern
        layer.fillRule = p.fillRule
        return layer
    }
}
