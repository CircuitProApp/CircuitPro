import Foundation

extension CanvasGraph {
    func selectionTarget(for id: NodeID) -> NodeID {
        if let pin = component(CanvasPin.self, for: id),
            let ownerID = pin.ownerID,
            !pin.isSelectable,
            hasAnyComponent(for: NodeID(ownerID))
        {
            return NodeID(ownerID)
        }
        if let pad = component(GraphPadComponent.self, for: id),
            let ownerID = pad.ownerID,
            !pad.isSelectable,
            hasAnyComponent(for: NodeID(ownerID))
        {
            return NodeID(ownerID)
        }
        return id
    }
}
