//
//  SymbolNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/6/25.
//

import AppKit

/// A scene graph node that represents an instance of a library `Symbol`.
/// It acts as a parent for `PrimitiveNode` children.
@Observable
final class SymbolNode: BaseNode {

    // MARK: - Properties

    var instance: SymbolInstance

    weak var wireEngine: WireEngine?

    override var isSelectable: Bool { true }

    // MARK: - Overridden Scene Graph Properties

    override var position: CGPoint {
        get { instance.position }
        set {
            instance.position = newValue

        }
    }

    override var rotation: CGFloat {
        get { instance.rotation }
        set {
            instance.rotation = newValue

        }
    }

    // MARK: - Initialization

    init?(id: UUID, instance: SymbolInstance, wireEngine: WireEngine? = nil) {
        guard let symbolDefinition = instance.definition else {
            print("Error: SymbolNode cannot be initialized without a hydrated SymbolInstance.definition.")
            return nil
        }

        self.instance = instance
        self.wireEngine = wireEngine

        super.init(id: id)

        // Create child nodes from the symbol's definition.
        let primitiveNodes = symbolDefinition.primitives.map { PrimitiveNode(primitive: $0) }
        self.children = primitiveNodes

        // Configure parent-child relationships.
        for child in self.children {
            child.parent = self

        }
    }

    // MARK: - Overridden Methods (Unchanged)
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
            guard child.isVisible else { continue }
            let childBox = child.interactionBounds
            let transformedChildBox = childBox.applying(child.localTransform)
            combinedBox = combinedBox.union(transformedChildBox)
        }

        return combinedBox
    }

}
