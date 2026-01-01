import Foundation

extension CanvasGraph {
    func selectionTarget(for id: GraphElementID) -> GraphElementID {
        guard case .node(let nodeID) = id else { return id }
        if let pin = component(CanvasPin.self, for: nodeID),
            let ownerID = pin.ownerID,
            !pin.isSelectable,
            hasAnyComponent(for: NodeID(ownerID))
        {
            return .node(NodeID(ownerID))
        }
        if let pad = component(GraphPadComponent.self, for: nodeID),
            let ownerID = pad.ownerID,
            !pad.isSelectable,
            hasAnyComponent(for: NodeID(ownerID))
        {
            return .node(NodeID(ownerID))
        }
        return id
    }
}
