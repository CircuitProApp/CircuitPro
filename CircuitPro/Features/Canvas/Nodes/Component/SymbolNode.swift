//
//  SymbolNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

/// A scene graph node that represents an instance of a library `Symbol`.
///
/// This is a container node that doesn't draw any geometry itself. Instead, it acts as a
/// parent for `PinNode`, `PrimitiveNode`, and `AnchoredTextNode` children. Its transform
/// (position and rotation) is applied to all its children automatically by the scene graph.
final class SymbolNode: BaseNode {

    // MARK: - Properties

    /// The instance-specific data for this symbol, like its position and overrides.
    let instance: SymbolInstance
    
    /// The library definition of the symbol, containing the template for primitives, pins, etc.
    let symbol: Symbol
    
    weak var graph: WireGraph?

    override var isSelectable: Bool { true }

    // MARK: - Overridden Scene Graph Properties

    /// Connects the node's position to its underlying data model.
    override var position: CGPoint {
        get { instance.position }
        set {
            // Note: No more manual delta calculations!
            // Just update the model. The renderer will handle the rest.
            instance.position = newValue
            onNeedsRedraw?()
        }
    }

    /// Connects the node's rotation to its underlying data model.
    override var rotation: CGFloat {
        get { instance.rotation }
        set {
            instance.rotation = newValue
            onNeedsRedraw?()
        }
    }

    // MARK: - Initialization

    init(id: UUID, instance: SymbolInstance, symbol: Symbol, resolvedTexts: [ResolvedText], graph: WireGraph? = nil) {
        self.instance = instance
        self.symbol = symbol
        self.graph = graph
        super.init(id: id)

        for primitive in symbol.primitives {
            self.addChild(PrimitiveNode(primitive: primitive))
        }

        // Pass the optional graph reference to the PinNode initializer.
        for pin in symbol.pins {
            self.addChild(PinNode(pin: pin, graph: self.graph))
        }
        
        for resolvedText in resolvedTexts {
            let textModel = TextModel(id: UUID(), text: resolvedText.text, position: resolvedText.relativePosition, font: resolvedText.font, color: resolvedText.color, alignment: resolvedText.alignment, cardinalRotation: resolvedText.cardinalRotation)
            let textNode = AnchoredTextNode(textModel: textModel, anchorPosition: resolvedText.anchorRelativePosition, anchorOwnerID: self.id, origin: resolvedText.origin)
            self.addChild(textNode)
        }
    }

    // MARK: - Overridden Methods

    override func makeHaloPath() -> CGPath? {
        let compositePath = CGMutablePath()

        // Iterate over all children to gather their individual halo paths.
        for child in self.children {
            guard let childNode = child as? BaseNode,
                  let childHalo = childNode.makeHaloPath() else {
                continue
            }
            
            // Add the child's path to the composite, applying the child's transform
            // to move it into the correct position within the symbol's coordinate space.
            compositePath.addPath(childHalo, transform: childNode.localTransform)
        }

        return compositePath.isEmpty ? nil : compositePath
    }
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // First, let the default BaseNode implementation check children.
        // This will correctly hit-test primitives and pins.
        if let hit = super.hitTest(point, tolerance: tolerance) {
            // If a selectable child (like a PinNode) is hit, return it.
            // If a non-selectable child (like a PrimitiveNode) is hit, BaseNode returns nil,
            // but we want to treat that as a hit on the SymbolNode itself.
            // The check `hit.node is PrimitiveNode` is a bit of a proxy for "non-selectable child".
            // A more robust solution might involve a specific property on the node.
            if hit.node.isSelectable {
                return hit
            }
        }

        // If no selectable children were hit, check if the point is within our core geometry.
        // This handles clicks on the "body" of the symbol.
        let coreGeometryBox = self.interactionBounds // This now correctly excludes text.
        if coreGeometryBox.contains(point) {
            return CanvasHitTarget(node: self, partIdentifier: nil, position: self.convert(point, to: nil))
        }
        
        // Finally, if still no hit, check the text nodes specifically.
        // If a text node is hit, we return the SymbolNode as the target.
        for child in children {
            guard let textNode = child as? AnchoredTextNode else { continue }
            
            let localPoint = point.applying(textNode.localTransform.inverted())
            if textNode.hitTest(localPoint, tolerance: tolerance) != nil {
                return CanvasHitTarget(node: self, partIdentifier: nil, position: self.convert(point, to: nil))
            }
        }

        return nil
    }

    override var interactionBounds: CGRect {
        var combinedBox = CGRect.null

        // Iterate over children, but only include "core" geometry.
        for child in children {
            // IGNORE AnchoredTextNode for interaction bounds.
            if child is AnchoredTextNode {
                continue
            }
            
            // For all other children (Primitives, Pins), include their bounds.
            guard child.isVisible else { continue }
            
            // Use the child's interactionBounds, not its boundingBox, for consistency.
            let childBox = child.interactionBounds
            let transformedChildBox = childBox.applying(child.localTransform)
            combinedBox = combinedBox.union(transformedChildBox)
        }
        
        return combinedBox
    }
}
