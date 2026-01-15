import AppKit

struct CKEmpty: CKView {
    typealias Body = CKGroup

    var body: CKGroup {
        .empty
    }
}

extension CKEmpty: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        CKRenderNode(geometry: .group, children: [], renderChildren: false)
    }
}
