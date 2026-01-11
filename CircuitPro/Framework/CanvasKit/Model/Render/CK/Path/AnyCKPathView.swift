import AppKit

struct AnyCKPathView {
    private let builder: (RenderContext) -> CGPath

    init<V: CKPathView>(_ view: V) {
        self.builder = { context in
            view.path(in: context, style: view.defaultStyle)
        }
    }

    init(path: CGPath) {
        self.builder = { _ in path }
    }

    func path(in context: RenderContext) -> CGPath {
        builder(context)
    }
}
