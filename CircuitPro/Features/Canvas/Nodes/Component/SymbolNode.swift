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
/// is applied to all its children automatically by the scene graph.
final class SymbolNode: BaseNode {

    // MARK: - Properties

    let instance: SymbolInstance
    let symbol: Symbol
    weak var graph: WireGraph?

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

    // CHANGED: The initializer now takes an array of the new `CircuitText.Resolved` model.
    init(id: UUID, instance: SymbolInstance, symbol: Symbol, resolvedTexts: [CircuitText.Resolved], graph: WireGraph? = nil) {
        self.instance = instance
        self.symbol = symbol
        self.graph = graph
        super.init(id: id)

        // Primitive and Pin creation is unchanged.
        for primitive in symbol.primitives {
            self.addChild(PrimitiveNode(primitive: primitive))
        }

        for pin in symbol.pins {
            self.addChild(PinNode(pin: pin, graph: self.graph))
        }
        
        // REFACTORED: The logic for creating text nodes is now dramatically simpler.
        // We just pass the resolved data model directly to the AnchoredTextNode's initializer.
        for resolvedText in resolvedTexts {
            let textNode = AnchoredTextNode(
                resolvedText: resolvedText,
                ownerID: self.id
            )
            self.addChild(textNode)
        }
    }

    // MARK: - Overridden Methods (These methods are unchanged)

    override func makeHaloPath() -> CGPath? {
        let compositePath = CGMutablePath()

        for child in self.children {
            guard let childNode = child as? BaseNode,
                  let childHalo = childNode.makeHaloPath() else {
                continue
            }
            compositePath.addPath(childHalo, transform: childNode.localTransform)
        }

        return compositePath.isEmpty ? nil : compositePath
    }
    
    override func hitTest(_ point: CGPoint, tolerance: CGFloat) -> CanvasHitTarget? {
        // First, let the default BaseNode implementation check children.
        if let hit = super.hitTest(point, tolerance: tolerance) {
            if hit.node.isSelectable {
                return hit
            }
        }

        // If no selectable children were hit, check if the point is within our core geometry.
        let coreGeometryBox = self.interactionBounds
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
            if child is AnchoredTextNode {
                continue
            }
            
            guard child.isVisible else { continue }
            let childBox = child.interactionBounds
            let transformedChildBox = childBox.applying(child.localTransform)
            combinedBox = combinedBox.union(transformedChildBox)
        }
        
        return combinedBox
    }
}
