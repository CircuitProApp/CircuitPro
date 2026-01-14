import CoreGraphics

struct SymbolRL: CKView {
    @CKContext var context

    var body: some CKView {
        CKGroup {
            for component in context.items.compactMap({ $0 as? ComponentInstance }) {
                SymbolView(component: component)
            }
        }
    }
}
