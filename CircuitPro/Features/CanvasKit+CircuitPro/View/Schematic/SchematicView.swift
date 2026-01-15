import AppKit

struct SchematicView: CKView {
    @CKContext var context
    let engine: any ConnectionEngine

    var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            WireView(engine: engine)
            for component in components {
                SymbolView(component: component)
            }
        }
    }
}
