//
//  FootprintNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
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

    init?(id: UUID, instance: FootprintInstance) {
        guard let footprintDefinition = instance.definition else {
            print("Error: FootprintNode cannot be initialized without a hydrated FootprintInstance.definition.")
            return nil
        }
        
        self.instance = instance
        super.init(id: id)

        // Create child PadNodes from the footprint's definition.
        let padNodes = footprintDefinition.pads.map { PadNode(pad: $0) }
        
        // In the future, you would also create nodes for footprint primitives (like silkscreen lines) here.
        // let primitiveNodes = footprintDefinition.primitives.map { PrimitiveNode(primitive: $0) }

        self.children = padNodes // + primitiveNodes
        
        // Configure parent-child relationships.
        for child in self.children {
            child.parent = self
            child.onNeedsRedraw = { [weak self] in self?.onNeedsRedraw?() }
        }
    }
    
    // MARK: - Overridden Methods
    
    // We can use the default implementation for hit-testing and halo paths for now,
    // as it delegates to the children (the PadNodes), which is what we want.
}
