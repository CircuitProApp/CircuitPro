import CoreGraphics
import Foundation

struct SandboxNode: CanvasItem, Transformable, Bounded, HitTestable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var cornerRadius: CGFloat
    var rotation: CGFloat
    var socketOffsets: [UUID: CGPoint]

    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        cornerRadius: CGFloat = 10,
        rotation: CGFloat = 0,
        socketOffsets: [UUID: CGPoint] = [:]
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.cornerRadius = cornerRadius
        self.rotation = rotation
        self.socketOffsets = socketOffsets
    }

    var boundingBox: CGRect {
        CGRect(
            x: position.x - size.width * 0.5,
            y: position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }
}
