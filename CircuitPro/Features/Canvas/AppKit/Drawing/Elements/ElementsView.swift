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
    var magnification: CGFloat = 1.0 {
        didSet { if oldValue != magnification { updateLayerTransforms() } }
    }

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
    private func updateElementLayers(from oldElements: [CanvasElement]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let oldElementMap = Dictionary(uniqueKeysWithValues: oldElements.map { ($0.id, $0) })
        let newElementMap = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
    
        let oldIDs = Set(oldElementMap.keys)
        let newIDs = Set(newElementMap.keys)

        // 1. Remove layers for elements that no longer exist.
        let removedIDs = oldIDs.subtracting(newIDs)
        for id in removedIDs {
            removeLayers(forElementID: id)
        }
        
        // 2. Add layers for new elements.
        let addedIDs = newIDs.subtracting(oldIDs)
        for id in addedIDs {
            if let element = newElementMap[id] {
                addLayers(for: element)
            }
        }
        
        // 3. Recreate layers for elements that have been modified.
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
    private func updateSelectionLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let allSelectedIDs = selectedIDs.union(marqueeSelectedIDs)
        let activeHaloIDs = Set(selectionHaloLayers.keys)
        
        // 1. Remove halos for elements that are no longer selected.
        let deselectedIDs = activeHaloIDs.subtracting(allSelectedIDs)
        for id in deselectedIDs {
            selectionHaloLayers[id]?.removeFromSuperlayer()
            selectionHaloLayers.removeValue(forKey: id)
        }
        
        // 2. Add halos for newly selected elements.
        let newlySelectedIDs = allSelectedIDs.subtracting(activeHaloIDs)
        for id in newlySelectedIDs {
            if let element = elements.first(where: { $0.id == id }) {
                addSelectionLayer(for: element)
            }
        }
        
        CATransaction.commit()
    }
    
    private func addSelectionLayer(for element: CanvasElement) {
        guard let hostLayer = layer,
              let path = element.drawable.selectionPath(),
              let bodyLayers = elementBodyLayers[element.id], !bodyLayers.isEmpty
        else { return }
        
        // 1. Create Halo Layer
        let haloLayer = createSelectionHaloLayer(for: element.drawable, path: path)
        selectionHaloLayers[element.id] = haloLayer
        
        // 2. Insert Halo Behind Body
        if let firstBodyLayer = bodyLayers.first {
            hostLayer.insertSublayer(haloLayer, below: firstBodyLayer)
        } else {
            hostLayer.addSublayer(haloLayer)
        }
    }

    // MARK: - Layer Creation
    private func createLayer(from p: DrawingParameters) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = p.path
        layer.fillColor = p.fillColor
        layer.strokeColor = p.strokeColor
        layer.lineWidth = p.lineWidth
        layer.lineCap = p.lineCap
        layer.lineJoin = p.lineJoin
        layer.lineDashPattern = p.lineDashPattern
        return layer
    }
    
    private func createSelectionHaloLayer(for drawable: Drawable, path: CGPath) -> CAShapeLayer {
        let haloWidth: CGFloat = 4 // Visual thickness in screen points
        let haloAlpha: CGFloat = 0.30

        let haloColor: CGColor
        if let prim = drawable as? any GraphicPrimitive {
            haloColor = prim.color.cgColor.copy(alpha: haloAlpha) ?? NSColor.systemBlue.withAlphaComponent(haloAlpha).cgColor
        } else {
            haloColor = NSColor.systemBlue.withAlphaComponent(haloAlpha).cgColor
        }
        
        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = nil
        layer.strokeColor = haloColor
        // Counter-scale the line width to ensure a constant visual thickness on screen
        layer.lineWidth = haloWidth / magnification
        layer.lineCap = .round
        layer.lineJoin = .round
        
        return layer
    }
    
    // MARK: - Magnification Handling
    private func updateLayerTransforms() {
        let haloWidth: CGFloat = 4.0
        // Counter-scale to maintain constant on-screen thickness.
        let scaledHaloWidth = haloWidth / max(magnification, 0.01)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Only selection halos need their line width adjusted.
        // Body layers' line widths are in model coordinates and scale with the view transform naturally.
        for (_, layer) in selectionHaloLayers {
            layer.lineWidth = scaledHaloWidth
        }
        
        CATransaction.commit()
    }
}
