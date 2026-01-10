import CoreGraphics
import Foundation

struct SandboxNode: CanvasItem, Transformable, HitTestable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var cornerRadius: CGFloat
    var rotation: CGFloat
    var sockets: [Socket]

    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        cornerRadius: CGFloat = 10,
        rotation: CGFloat = 0,
        sockets: [Socket] = []
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.cornerRadius = cornerRadius
        self.rotation = rotation
        self.sockets = sockets
    }

    var boundingBox: CGRect {
        CGRect(
            x: position.x - size.width * 0.5,
            y: position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }

    func hitTest(point: CGPoint, tolerance: CGFloat) -> Bool {
        boundingBox.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    func socketPosition(for socket: Socket) -> CGPoint {
        CGPoint(x: position.x + socket.offset.x, y: position.y + socket.offset.y)
    }
}
