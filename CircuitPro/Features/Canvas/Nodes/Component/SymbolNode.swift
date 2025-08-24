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
@Observable
final class SymbolNode: BaseNode {

    // MARK: - Properties

    var instance: SymbolInstance {
        didSet {
            onNeedsRedraw?()
        }
    }
    let symbol: Symbol
    weak var graph: WireGraph?

    override var isSelectable: Bool { true }
    
    let resolvedTexts: [CircuitText.Resolved]

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
        
        self.resolvedTexts = resolvedTexts
        
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
                ownerInstance: self.instance
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
        // First, delegate to the base implementation to hit-test all children.
        // This correctly finds hits on selectable children (like pins or text nodes)
        // and returns a target pointing to that specific child.
        if let childHit = super.hitTest(point, tolerance: tolerance) {
            return childHit
        }

        // If no children were hit, check if the point intersects with this symbol's
        // own "body" geometry (which excludes text nodes).
        if interactionBounds.contains(point) {
            return CanvasHitTarget(node: self, partIdentifier: nil, position: self.convert(point, to: nil))
        }

        // If neither children nor the body were hit, there's no hit.
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
