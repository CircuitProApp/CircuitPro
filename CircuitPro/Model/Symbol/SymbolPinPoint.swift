import CoreGraphics
import Foundation

struct SymbolPinPoint: CanvasItem, ConnectionPoint {
    let id: UUID
    let symbolID: UUID
    let pinID: UUID
    let position: CGPoint

    init(symbolID: UUID, pinID: UUID, position: CGPoint) {
        self.symbolID = symbolID
        self.pinID = pinID
        self.position = position
        self.id = UUID(name: "\(symbolID.uuidString)|\(pinID.uuidString)", namespace: Self.namespace)
    }

    private static let namespace = UUID(uuidString: "B0BC10B2-9A8E-4AF2-9F2C-9CB5A7D6B918")!
}
