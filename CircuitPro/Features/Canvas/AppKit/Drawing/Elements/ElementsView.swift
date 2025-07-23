import AppKit

final class ElementsView: NSView {

    // MARK: - Data
    var elements: [CanvasElement] = [] {
        didSet { updateElementLayers(from: oldValue) }
    }
    var selectedIDs: Set<UUID> = [] {
        didSet { updateSelectionLayers() }
    }
    var marqueeSelectedIDs: Set<UUID> = [] {
        didSet { updateSelectionLayers() }
    }
    
    // The view still needs to know the magnification for other potential features,
    // but it no longer needs a didSet observer for halo scaling.
    var magnification: CGFloat = 1.0

    // MARK: – Layer Storage
    private var elementBodyLayers: [UUID: [CAShapeLayer]] = [:]
    private var selectionHaloLayers: [UUID: CAShapeLayer] = [:]

    // MARK: - Init
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
        layer?.isGeometryFlipped = true
    }

    // MARK: - View Configuration
    override var isOpaque: Bool { false }
    override func hitTest(_: NSPoint) -> NSView? { nil }

    // MARK: - Element Layer Management
    // This section remains unchanged.
    private func updateElementLayers(from oldElements: [CanvasElement]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let oldElementMap = Dictionary(uniqueKeysWithValues: oldElements.map { ($0.id, $0) })
        let newElementMap = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
    
        let oldIDs = Set(oldElementMap.keys)
        let newIDs = Set(newElementMap.keys)

        let removedIDs = oldIDs.subtracting(newIDs)
        for id in removedIDs {
            removeLayers(forElementID: id)
        }
        
        let addedIDs = newIDs.subtracting(oldIDs)
        for id in addedIDs {
            if let element = newElementMap[id] {
                addLayers(for: element)
            }
        }
        
        let potentiallyModifiedIDs = newIDs.intersection(oldIDs)
        for id in potentiallyModifiedIDs {
            if let old = oldElementMap[id], let new = newElementMap[id], new != old {
                removeLayers(forElementID: id)
                addLayers(for: new)
            }
        }

        CATransaction.commit()
    }

    private func addLayers(for element: CanvasElement) {
        guard let hostLayer = layer else { return }
        
        // 1. Create Body Layers
        let bodyParams = element.drawable.makeBodyParameters()
        let newBodyLayers = bodyParams.map { createLayer(from: $0) }
        
        elementBodyLayers[element.id] = newBodyLayers
        newBodyLayers.forEach { hostLayer.addSublayer($0) }
        
        // 2. Re-apply selection if this element is selected
        let allSelected = selectedIDs.union(marqueeSelectedIDs)
        if allSelected.contains(element.id) {
            addSelectionLayer(for: element)
        }
    }

    private func removeLayers(forElementID id: UUID) {
        elementBodyLayers[id]?.forEach { $0.removeFromSuperlayer() }
        elementBodyLayers.removeValue(forKey: id)
        
        selectionHaloLayers[id]?.removeFromSuperlayer()
        selectionHaloLayers.removeValue(forKey: id)
    }
    
    // MARK: - Selection Layer Management
    // This section remains unchanged.
    private func updateSelectionLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let allSelectedIDs = selectedIDs.union(marqueeSelectedIDs)
        let activeHaloIDs = Set(selectionHaloLayers.keys)
        
        let deselectedIDs = activeHaloIDs.subtracting(allSelectedIDs)
        for id in deselectedIDs {
            selectionHaloLayers[id]?.removeFromSuperlayer()
            selectionHaloLayers.removeValue(forKey: id)
        }
        
        let newlySelectedIDs = allSelectedIDs.subtracting(activeHaloIDs)
        for id in newlySelectedIDs {
            if let element = elements.first(where: { $0.id == id }) {
                addSelectionLayer(for: element)
            }
        }
        
        CATransaction.commit()
    }
    
    // --- UPDATED METHOD ---
    private func addSelectionLayer(for element: CanvasElement) {
        // 1. Ensure the element can provide a halo and has body layers to draw behind.
        guard let hostLayer = layer,
              let haloParams = element.drawable.makeHaloParameters(),
              let bodyLayers = elementBodyLayers[element.id], !bodyLayers.isEmpty
        else { return }
        
        // 2. Create the halo layer directly from the parameters provided by the drawable.
        let haloLayer = createLayer(from: haloParams)
        selectionHaloLayers[element.id] = haloLayer
        
        // 3. Insert the halo behind the body.
        if let firstBodyLayer = bodyLayers.first {
            hostLayer.insertSublayer(haloLayer, below: firstBodyLayer)
        } else {
            hostLayer.addSublayer(haloLayer)
        }
    }

    // MARK: - Layer Creation
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
    
    // The specialized createSelectionHaloLayer and updateLayerTransforms methods
    // have been removed as they are no longer necessary.
}
