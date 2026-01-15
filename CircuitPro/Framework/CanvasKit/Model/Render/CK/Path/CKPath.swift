import AppKit

struct CKPath: CKView {
    private let builder: (RenderContext) -> CGPath

    init(path: CGPath) {
        self.builder = { _ in path }
    }
}

extension CKPath: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(
            geometry: .path { context in
                builder(context)
            }
        )
    }
}
