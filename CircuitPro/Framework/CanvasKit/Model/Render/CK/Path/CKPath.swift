import AppKit

struct CKPath: CKPathView {
    private let builder: (RenderContext) -> CGPath

    init(path: CGPath) {
        self.builder = { _ in path }
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
