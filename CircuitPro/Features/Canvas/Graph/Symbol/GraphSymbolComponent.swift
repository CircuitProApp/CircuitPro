import CoreGraphics
import Foundation

struct GraphSymbolComponent: GraphComponent {
    var ownerID: UUID
    var position: CGPoint
    var rotation: CGFloat
    var primitives: [AnyCanvasPrimitive]
}

extension GraphSymbolComponent {
    var ownerTransform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
    }

    func localInteractionBounds() -> CGRect? {
        var combined = CGRect.null

        for primitive in primitives {
            var box = primitive.boundingBox
            let primTransform = CGAffineTransform(translationX: primitive.position.x, y: primitive.position.y)
                .rotated(by: primitive.rotation)
            box = box.applying(primTransform)
            combined = combined.union(box)
        }

        return combined.isNull ? nil : combined
    }

    func worldInteractionBounds() -> CGRect? {
        guard let local = localInteractionBounds() else { return nil }
        return local.applying(ownerTransform)
    }
}

extension GraphSymbolComponent: Transformable {}
