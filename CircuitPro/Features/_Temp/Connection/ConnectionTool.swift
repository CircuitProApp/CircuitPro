import SwiftUI
import AppKit

struct ConnectionTool: CanvasTool, Equatable, Hashable {
    let id = "connection"
    let symbolName = CircuitProSymbols.Graphic.line
    let label = "Connection"

    private let controller: ConnectionController

    init(controller: ConnectionController = ConnectionController(repository: NetRepository())) {
        self.controller = controller
    }

    mutating func handleTap(at loc: CGPoint, context: CanvasToolContext) -> CanvasElement? {
        controller.handleTap(at: loc, context: context)
    }

    mutating func drawPreview(in ctx: CGContext, mouse: CGPoint, context: CanvasToolContext) {
        controller.drawPreview(in: ctx, mouse: mouse, context: context)
    }

    mutating func handleEscape() { controller.handleEscape() }
    mutating func handleBackspace() { controller.handleBackspace() }

    static func merge(
        _ newElement: ConnectionElement,
        into elements: inout [CanvasElement],
        repository: NetRepository
    ) -> ConnectionElement {
        var masterNet = newElement.net
        for index in (0..<elements.count).reversed() {
            guard case .connection(let existingConnection) = elements[index],
                  existingConnection.id != newElement.id else { continue }
            var existingNet = existingConnection.net
            guard repository.mergePolicy.shouldMerge(masterNet, into: existingNet, at: .afterCommit) else { continue }
            let wasMerged = Net.findAndMergeIntentionalIntersections(
                between: &masterNet,
                and: &existingNet
            )
            if wasMerged {
                masterNet.nodeByID.merge(existingNet.nodeByID) { current, _ in current }
                masterNet.edges.append(contentsOf: existingNet.edges)
                elements.remove(at: index)
            }
        }
        masterNet.mergeColinearEdges()
        return ConnectionElement(id: masterNet.id, net: masterNet)
    }

    static func == (lhs: ConnectionTool, rhs: ConnectionTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
