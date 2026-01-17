import AppKit

struct LayoutView: CKView {
    @CKContext var context
    let traceEngine: TraceEngine

    var body: some CKView {
        let components = context.items.compactMap { $0 as? ComponentInstance }
        CKGroup {
            TraceView(traceEngine: traceEngine)
            for component in components {
                FootprintView(component: component)
            }
        }
    }
}
