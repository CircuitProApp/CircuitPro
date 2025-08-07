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

    init(instance: SymbolInstance, symbol: Symbol, resolvedTexts: [ResolvedText]) {
        self.instance = instance
        self.symbol = symbol
        // Initialize the BaseNode with the instance's ID.
        super.init(id: instance.id)

        // The SymbolNode is now the single source of truth for its transform.
        // We no longer pass the parent transform down to children during creation.
        
        // 1. Create and add child nodes for each primitive.
        for primitive in symbol.primitives {
            let primitiveNode = PrimitiveNode(primitive: primitive)
            self.addChild(primitiveNode)
        }

        // 2. Create and add child nodes for each pin.
        for pin in symbol.pins {
            let pinNode = PinNode(pin: pin)
            self.addChild(pinNode)
        }
        
        // 3. Create and add child nodes for each resolved text element.
        for resolvedText in resolvedTexts {
            let textModel = TextModel(
                id: UUID(),
                text: resolvedText.text,
                position: resolvedText.relativePosition, // Position is relative to the symbol
                font: resolvedText.font,
                color: resolvedText.color,
                alignment: resolvedText.alignment,
                cardinalRotation: resolvedText.cardinalRotation
            )

            let textNode = AnchoredTextNode(
                textModel: textModel,
                anchorPosition: resolvedText.anchorRelativePosition, // Anchor is also relative
                anchorOwnerID: self.id,
                origin: resolvedText.origin
            )
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
}
