import AppKit

struct LayoutView: CKView {
    @CKContext var context

    var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            for component in components {
                FootprintView(component: component)
            }
        }
    }
}
