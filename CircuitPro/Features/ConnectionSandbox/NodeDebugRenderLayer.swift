import AppKit

final class NodeDebugRenderLayer: RenderLayer {
    private let contentLayer = CALayer()

    func install(on hostLayer: CALayer) {
        hostLayer.addSublayer(contentLayer)
    }

    func update(using context: RenderContext) {
        contentLayer.frame = context.hostViewBounds
        contentLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        for item in context.items {
            guard let node = item as? SandboxNode else { continue }

            let rect = CGRect(
                x: node.position.x - node.size.width * 0.5,
                y: node.position.y - node.size.height * 0.5,
                width: node.size.width,
                height: node.size.height
            )
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: node.cornerRadius,
                cornerHeight: node.cornerRadius,
                transform: nil
            )

            let shape = CAShapeLayer()
            shape.path = path
            shape.fillColor = NSColor.systemGray.withAlphaComponent(0.3).cgColor
            shape.strokeColor = NSColor.systemGray.cgColor
            shape.lineWidth = 2
            contentLayer.addSublayer(shape)
        }
    }
}
