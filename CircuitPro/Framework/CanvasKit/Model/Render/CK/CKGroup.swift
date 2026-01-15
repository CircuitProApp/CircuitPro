import AppKit

struct CKGroup: CKView {
    typealias Body = CKGroup
    let children: [AnyCKView]
    static let empty = CKGroup()

    init(_ children: [AnyCKView] = []) {
        self.children = children
    }

    init(@CKViewBuilder _ content: () -> CKGroup) {
        self = content()
    }

    var body: CKGroup {
        .empty
    }
}

extension CKGroup: CKNodeView {
    func makeNode(in context: RenderContext) -> CKRenderNode? {
        var nodes: [CKRenderNode] = []
        nodes.reserveCapacity(children.count)
        for (index, child) in children.enumerated() {
            guard let node = child.makeNode(in: context, index: index) else {
                return nil
            }
            nodes.append(node)
        }
        return CKRenderNode(geometry: .group, children: nodes, renderChildren: true)
    }
}
