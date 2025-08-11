//
//  CanvasNode.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/4/25.
//

import CoreGraphics
import AppKit

/// The core protocol for any object that can exist on the canvas scene graph.
///
/// It defines an object that has an identity, can be drawn and interacted with,
/// occupies a bounding box, and exists within a parent-child hierarchy.
protocol CanvasNode: AnyObject, CanvasElement {

    // MARK: - Scene Graph API
    
    /// A weak reference to the parent node. This must be weak to prevent retain cycles.
    var parent: BaseNode? { get set }

    /// An array of child nodes.
    var children: [BaseNode] { get set }
    
    var isVisible: Bool { get set }
    var isSelectable: Bool { get }
    
    var localTransform: CGAffineTransform { get }
    var worldTransform: CGAffineTransform { get }

    // Methods are updated to use the concrete `BaseNode` type.
    func addChild(_ node: BaseNode)
    func removeFromParent()
    func convert(_ point: CGPoint, from sourceNode: BaseNode?) -> CGPoint
    func convert(_ point: CGPoint, to destinationNode: BaseNode?) -> CGPoint
}
