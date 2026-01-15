import AppKit

struct AnyCKView: CKView {
    typealias Body = CKGroup
    private let renderer: (RenderContext) -> [DrawingPrimitive]
    private let pathProvider: (RenderContext) -> [CGPath]
    private let hitTestPathProvider: ((RenderContext) -> CGPath?)?

    init<V: CKView>(_ view: V) {
        self.renderer = view._render
        self.pathProvider = view._paths
        if let hitTestable = view as? any CKHitTestable {
            self.hitTestPathProvider = { context in
                let path = hitTestable.hitTestPath(in: context)
                return path.isEmpty ? nil : path
            }
        } else {
            self.hitTestPathProvider = nil
        }
    }

    var body: CKGroup {
        .empty
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        renderer(context)
    }

    func _paths(in context: RenderContext) -> [CGPath] {
        pathProvider(context)
    }

    func hitTestPath(in context: RenderContext) -> CGPath? {
        hitTestPathProvider?(context)
    }
}
