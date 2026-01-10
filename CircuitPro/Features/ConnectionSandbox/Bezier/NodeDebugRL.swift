import AppKit

struct NodeDebugRL: CKRenderLayer {
    @CKContext var context

    var body: CKLayer {
        let path = CGMutablePath()
        for item in context.items {
            guard let node = item as? SandboxNode else { continue }
            let rect = CGRect(
                x: node.position.x - node.size.width * 0.5,
                y: node.position.y - node.size.height * 0.5,
                width: node.size.width,
                height: node.size.height
            )
            path.addPath(
                CGPath(
                    roundedRect: rect,
                    cornerWidth: node.cornerRadius,
                    cornerHeight: node.cornerRadius,
                    transform: nil
                )
            )
        }

        return CKLayer {
            CKPath(path: path)
                .fill(NSColor.systemGray.withAlphaComponent(0.3).cgColor)
                .stroke(NSColor.systemGray.cgColor, width: 2)
        }
    }
}
