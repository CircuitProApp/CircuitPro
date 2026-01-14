import AppKit

struct CKEmpty: CKView {
    typealias Body = CKGroup

    var body: CKGroup {
        .empty
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        []
    }
}
