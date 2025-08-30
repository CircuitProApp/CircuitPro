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
    // MARK: - Properties

    var instance: SymbolInstance {
        didSet {
            // This is still useful for triggering redraws on property changes.
            onNeedsRedraw?()
        }
    }
    
    // --- REMOVED ---
    // The separate 'symbol' property is now redundant. We will use 'instance.definition'.
    // let symbol: SymbolDefinition
    
    weak var graph: WireGraph?

    override var isSelectable: Bool { true }
    
    // This remains a good way to pass in the calculated text.
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

    // --- REFACTORED INITIALIZER ---
    // It no longer accepts a separate 'symbol'. It relies on the definition
    // already being attached to the instance.
    init?(id: UUID, instance: SymbolInstance, resolvedTexts: [CircuitText.Resolved], graph: WireGraph? = nil) {
        // Add a guard to ensure the instance has been properly hydrated.
        // If not, we can't build the node, so the initializer fails.
        guard let symbolDefinition = instance.definition else {
            print("Error: SymbolNode cannot be initialized without a hydrated SymbolInstance.definition.")
            return nil
        }
        
        self.instance = instance
        self.graph = graph
        self.resolvedTexts = resolvedTexts
        
        super.init(id: id)

        // --- UPDATED LOGIC ---
        // Create children using the definition from the instance.
        for primitive in symbolDefinition.primitives {
            self.addChild(PrimitiveNode(primitive: primitive))
        }

        for pin in symbolDefinition.pins {
            self.addChild(PinNode(pin: pin, graph: self.graph))
        }
        
        // This logic is unchanged but is now more robust.
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
