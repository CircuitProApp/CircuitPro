import AppKit

struct CKEmpty: CKView {
    typealias Body = Never

    var body: Never {
        fatalError("CKEmpty has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        []
    }
}
