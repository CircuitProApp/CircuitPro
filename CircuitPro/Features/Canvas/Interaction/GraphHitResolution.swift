import Foundation

extension RenderContext {
    func selectionTarget(for id: GraphElementID) -> GraphElementID {
        guard case .node(let nodeID) = id else { return id }
        let itemID = nodeID.rawValue
        guard let item = items.first(where: { $0.id == itemID }) else { return id }

        if let pin = item as? CanvasPin,
            let ownerID = pin.ownerID,
            !pin.isSelectable
        {
            return .node(NodeID(ownerID))
        }
        if let pad = item as? CanvasPad,
            let ownerID = pad.ownerID,
            !pad.isSelectable
        {
            return .node(NodeID(ownerID))
        }
        return id
    }
}
