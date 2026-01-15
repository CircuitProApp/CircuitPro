import AppKit

struct SchematicView: CKView {
    @CKContext var context

    var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            WireView()
            for component in components {
                SymbolView(component: component)
            }
        }
    }
}
