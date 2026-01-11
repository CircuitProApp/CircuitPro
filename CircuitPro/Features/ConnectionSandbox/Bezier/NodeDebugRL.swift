import AppKit

struct NodeDebugRL: CKView {
    @CKContext var context

     @CKViewBuilder var body: some CKView {
        let path = nodePath(items: context.items)
        CKGroup {
            CKPath(path: path)
                .fill(NSColor.systemGray.withAlphaComponent(0.3).cgColor)
                .stroke(NSColor.systemGray.cgColor, width: 2)
        }
    }

    private func nodePath(items: [any CanvasItem]) -> CGPath {
        let path = CGMutablePath()
        for item in items {
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
        return path
    }
}
