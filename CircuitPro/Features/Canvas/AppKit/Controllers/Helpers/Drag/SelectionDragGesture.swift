import AppKit

final class SelectionDragGesture: CanvasDragGesture {

    unowned let controller: CanvasController

    private var origin: CGPoint?
    private var didMove = false
    private let threshold: CGFloat = 4.0

    private var originalNodePositions: [UUID: CGPoint] = [:]
    private var dragAnchor: (position: CGPoint, size: CGSize?, snapsToCenter: Bool)?

    init(controller: CanvasController) {
        self.controller = controller
    }

    func begin(at point: CGPoint, with hitTarget: CanvasHitTarget, event: NSEvent) -> Bool {
        guard !controller.selectedNodes.isEmpty else { return false }
        
        let selectedIDs = Set(controller.selectedNodes.map { $0.id })
        let isDraggable = hitTarget.ownerPath.contains { selectedIDs.contains($0) }
        guard isDraggable else { return false }

        origin = point
        didMove = false
        originalNodePositions.removeAll()
        dragAnchor = nil

        for node in controller.selectedNodes {
            originalNodePositions[node.id] = node.position
        }
        
        if let hitID = hitTarget.selectableID, let hitNode = controller.selectedNodes.first(where: { $0.id == hitID }) {
            var size: CGSize?
            var snapsToCenter = true
            
            if let primitiveNode = hitNode as? PrimitiveNode {
                size = primitiveNode.primitive.size
                snapsToCenter = primitiveNode.primitive.snapsToCenter
            }
            dragAnchor = (hitNode.position, size, snapsToCenter)
        }

        if selectedIDs.contains(where: { controller.schematicGraph.edges[$0] != nil }) {
            controller.schematicGraph.beginDrag(selectedIDs: selectedIDs)
        }

        return true
    }
    
    func drag(to point: CGPoint) {
        guard let origin = origin else { return }

        let rawDelta = point - origin
        if !didMove && hypot(rawDelta.x, rawDelta.y) < threshold {
            return
        }
        didMove = true

        let moveDelta = calculateSnappedDelta(rawDelta: rawDelta)
        
        // THIS IS NOW CORRECT.
        // `controller.selectedNodes` is [any CanvasNode], an array of class references.
        // `node` is a reference, not a copy, so mutating its properties works.
        controller.selectedNodes.forEach { node in
            if let originalPosition = originalNodePositions[node.id] {
                node.position = originalPosition + moveDelta
            }
        }
        
        controller.schematicGraph.updateDrag(by: moveDelta)
    }

    private func calculateSnappedDelta(rawDelta: CGPoint) -> CGPoint {
        guard let anchor = dragAnchor else {
            let snappedX = controller.snap(CGPoint(x: rawDelta.x, y: 0)).x
            let snappedY = controller.snap(CGPoint(x: 0, y: rawDelta.y)).y
            return CGPoint(x: snappedX, y: snappedY)
        }
        
        let newAnchorPos = anchor.position + rawDelta
        let snappedNewAnchorPos: CGPoint

        if let size = anchor.size, size != .zero, !anchor.snapsToCenter {
            let halfSize = CGPoint(x: size.width / 2, y: size.height / 2)
            let originalCorner = anchor.position - halfSize
            let newCorner = newAnchorPos - halfSize
            let snappedNewCorner = controller.snap(newCorner)
            let cornerDelta = snappedNewCorner - originalCorner
            snappedNewAnchorPos = anchor.position + cornerDelta
        } else {
            snappedNewAnchorPos = controller.snap(newAnchorPos)
        }
        
        return snappedNewAnchorPos - anchor.position
    }

    func end() {
        if didMove {
            controller.schematicGraph.endDrag()
        }
        
        origin = nil
        didMove = false
        dragAnchor = nil
        originalNodePositions.removeAll()
    }
}
