import AppKit

struct CKPath: CKPathView {
    private let builder: (RenderContext) -> CGPath

    init(path: CGPath) {
        self.builder = { _ in path }
    }

    init(@CKPathBuilder _ content: () -> [AnyCKPathView]) {
        let children = content()
        self.builder = { context in
            let merged = CGMutablePath()
            for child in children {
                let childPath = child.path(in: context)
                if !childPath.isEmpty {
                    merged.addPath(childPath)
                }
            }
            return merged
        }
    }

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        let base = builder(context)
        guard let position = style.position else {
            return base
        }
        var transform = CGAffineTransform(translationX: position.x, y: position.y)
        return base.copy(using: &transform) ?? base
    }
}
