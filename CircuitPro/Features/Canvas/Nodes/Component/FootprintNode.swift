//
//  FootprintNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 01.06.25.
//

import AppKit

/// A scene graph node that represents an instance of a library `Footprint`.
/// It acts as a parent for `PadNode` and other layout-specific primitive nodes.
@Observable
final class FootprintNode: BaseNode {
    
    // MARK: - Properties
    
    var instance: FootprintInstance {
        didSet { onNeedsRedraw?() }
    }
    
    // The FootprintNode itself is the selectable entity.
    override var isSelectable: Bool { true }
    
    // MARK: - Overridden Scene Graph Properties
    
    override var position: CGPoint {
        get { instance.position }
        set {
            instance.position = newValue
            onNeedsRedraw?()
        }
    }
    
    override var rotation: CGFloat {
        get { instance.rotation }
        set {
            instance.rotation = newValue
            onNeedsRedraw?()
        }
    }
    
    // MARK: - Initialization
    
    init?(id: UUID, instance: FootprintInstance, canvasLayers: [CanvasLayer]) {
        guard let footprintDefinition = instance.definition else { return nil }
        
        self.instance = instance
        super.init(id: id)
        
        let padNodes = footprintDefinition.pads.map { PadNode(pad: $0) }
        let primitiveNodes = footprintDefinition.primitives.map { PrimitiveNode(primitive: $0) }
        
        self.children = padNodes + primitiveNodes
        
        // Resolve the generic layer IDs on child primitives to specific board layer IDs.
        resolveChildLayerIDs(canvasLayers: canvasLayers)
        
        for child in self.children {
            child.parent = self
            child.onNeedsRedraw = { [weak self] in self?.onNeedsRedraw?() }
        }
    }
    
    /// Iterates through child primitives and updates their generic `layerId` to the
    /// specific `layerId` from the board stackup, based on the footprint's placement.
    private func resolveChildLayerIDs(canvasLayers: [CanvasLayer]) {
        guard case .placed(let side) = instance.placement else { return }
        
        // --- THIS LOGIC IS NOW ROBUST AND TYPE-SAFE ---
        
        for child in children {
            guard let primitiveNode = child as? PrimitiveNode,
                  let genericLayerID = primitiveNode.layerId else { continue }
            
            // 1. Find the generic LayerKind that corresponds to the primitive's stable ID.
            if let genericKind = LayerKind.allCases.first(where: { $0.stableId == genericLayerID }) {
                
                // 2. Find the specific CanvasLayer that matches both the kind and the side.
                if let specificLayer = canvasLayers.first(where: { canvasLayer in
                    // a. Safely cast the 'kind' property back to our app-specific LayerType.
                    guard let layerType = canvasLayer.kind as? LayerType else { return false }
                    
                    // b. Check if the generic kind matches.
                    let kindMatches = layerType.kind == genericKind
                    
                    // c. Check if the side matches.
                    var sideMatches = false
                    if side == .front && layerType.side == .front {
                        sideMatches = true
                    } else if side == .back && layerType.side == .back {
                        sideMatches = true
                    }
                    
                    return kindMatches && sideMatches
                }) {
                    // 3. Success! Update the child node's layerId to the specific ID.
                    primitiveNode.layerId = specificLayer.id
                }
            }
        }
    }
    
    // MARK: - Overridden Interaction and Drawing Methods
    
    /// Creates a unified halo path that combines the halos of all child nodes (pads and primitives).
    override func makeHaloPath() -> CGPath? {
        let compositePath = CGMutablePath()
        
        for child in self.children {
            guard let childNode = child as? BaseNode,
                  let childHalo = childNode.makeHaloPath() else {
                continue
            }
            // Transform the child's local halo path into this node's coordinate space
            // and add it to the composite path.
            compositePath.addPath(childHalo, transform: childNode.localTransform)
        }
        
        return compositePath.isEmpty ? nil : compositePath
    }
    
    /// Determines if a point hits any part of the footprint. If it does, it returns
    /// a hit target for the `FootprintNode` itself, not its children.
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // We do NOT call super.hitTest here because we do not want to return a child node.
        // We only want to know if the click was inside our overall boundary.
        
        // The interactionBounds rectangle is already in our local coordinate space.
        if interactionBounds.contains(point) {
            // The hit was successful. Return a target pointing to *this* node.
            return CanvasHitTarget(node: self, partIdentifier: nil, position: self.convert(point, to: nil))
        }
        
        // If the point is not within our bounds, there's no hit.
        return nil
    }
    
    /// Calculates the bounding box that encloses all child nodes (pads and primitives).
    override var interactionBounds: CGRect {
        var combinedBox = CGRect.null
        
        // Iterate over all children to create a single interaction boundary.
        for child in children {
            guard child.isVisible else { continue }
            let childBox = child.interactionBounds
            let transformedChildBox = childBox.applying(child.localTransform)
            combinedBox = combinedBox.union(transformedChildBox)
        }
        
        return combinedBox
    }
}
