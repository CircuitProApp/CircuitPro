import AppKit

struct AnyCKView: CKView {
    typealias Body = Never
    private let renderer: (RenderContext) -> [DrawingPrimitive]

    init<V: CKView>(_ view: V) {
        self.renderer = view._render
    }

    var body: Never {
        fatalError("AnyCKView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        renderer(context)
    }
}
