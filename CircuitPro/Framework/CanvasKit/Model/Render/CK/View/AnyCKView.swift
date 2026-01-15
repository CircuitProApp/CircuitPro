import AppKit

struct AnyCKView: CKView {
    typealias Body = CKGroup
    private let nodeProvider: (RenderContext) -> CKRenderNode?
    private let prepareState: (() -> Void)?

    init<V: CKView>(_ view: V) {
        self.nodeProvider = { context in
            view.makeNode(in: context)
        }
        self.prepareState = {
            CKStateRegistry.prepare(view)
        }
    }

    var body: CKGroup {
        .empty
    }

    func makeNode(in context: RenderContext) -> CKRenderNode? {
        prepareState?()
        return nodeProvider(context)
    }

    func makeNode(in context: RenderContext, index: Int) -> CKRenderNode? {
        return CKContextStorage.withViewScope(index: index) {
            prepareState?()
            return nodeProvider(context)
        }
    }
}
