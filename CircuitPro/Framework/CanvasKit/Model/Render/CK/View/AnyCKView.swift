import AppKit

struct AnyCKView: CKView {
    typealias Body = CKGroup
    private let renderer: (RenderContext) -> [DrawingPrimitive]
    private let pathProvider: (RenderContext) -> [CGPath]

    init<V: CKView>(_ view: V) {
        self.renderer = view._render
        self.pathProvider = view._paths
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
}
