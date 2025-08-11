import AppKit

/// Renders the editing handles for a single selected `HandleEditable` node.
class HandlesRenderLayer: RenderLayer {
    
    private let shapeLayer = CAShapeLayer()

    func install(on hostLayer: CALayer) {
        // Configure constant properties that never change.
        shapeLayer.fillColor = NSColor.white.cgColor
        shapeLayer.strokeColor = NSColor.systemBlue.cgColor
        shapeLayer.zPosition = 1_000_000 // A high value to ensure handles appear on top of all other content.
        
        hostLayer.addSublayer(shapeLayer)
    }

    func update(using context: RenderContext) {
        // Attempt to find a single, selected, editable node.
        guard let node = findEditableNode(in: context) else {
            // If no valid node is found, hide the layer and clear its path.
            shapeLayer.isHidden = true
            shapeLayer.path = nil
            return
        }
        
        // An editable node was found, so ensure the layer is visible.
        shapeLayer.isHidden = false
        
        let handles = node.editable.handles()
        let path = CGMutablePath()
        
        // Calculate handle size and line width based on canvas magnification
        // so they appear to have a constant size on screen.
        let handleScreenSize: CGFloat = 10.0
        let sizeInWorldCoords = handleScreenSize / max(context.magnification, .ulpOfOne)
        let half = sizeInWorldCoords / 2.0
        let lineWidth = 1.0 / max(context.magnification, .ulpOfOne)

        // Get the node's world transform to correctly position the handles.
        let transform = node.node.worldTransform
        
        for handle in handles {
            // Convert the handle's local position to world coordinates.
            let worldHandlePosition = handle.position.applying(transform)
            
            let handleRect = CGRect(
                x: worldHandlePosition.x - half,
                y: worldHandlePosition.y - half,
                width: sizeInWorldCoords,
                height: sizeInWorldCoords
            )
            path.addEllipse(in: handleRect)
        }
        
        // Update the layer's path and line width.
        shapeLayer.path = path
        shapeLayer.lineWidth = lineWidth
    }
    
    /// Finds a single selected node that conforms to `HandleEditable`.
    private func findEditableNode(in context: RenderContext) -> (node: BaseNode, editable: HandleEditable)? {
        guard context.highlightedNodeIDs.count == 1,
              let nodeID = context.highlightedNodeIDs.first else {
            return nil
        }
        
        guard let node = findNode(with: nodeID, in: context.sceneRoot),
              let editableNode = node as? HandleEditable,
              !editableNode.handles().isEmpty else {
            return nil
        }
        
        return (node, editableNode)
    }
    
    /// Recursively searches the scene graph for a node with a given ID.
    private func findNode(with id: UUID, in root: BaseNode) -> BaseNode? {
        if root.id == id { return root }
        
        for child in root.children {
            if let childNode = child as? BaseNode,
               let found = findNode(with: id, in: childNode) {
                return found
            }
        }
        return nil
    }
}