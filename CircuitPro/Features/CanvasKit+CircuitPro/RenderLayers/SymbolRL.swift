import CoreGraphics

struct SymbolRL: CKView {
    @CKContext var context

    var body: some CKView {
        CKGroup {
            for component in context.items.compactMap({ $0 as? ComponentInstance }) {
                SymbolView(component: component)
                    .hoverable(component.id)
                    .selectable(component.id)
                    .onDragGesture { delta in
                        context.update(component.id, as: ComponentInstance.self) { component in
                            component.translate(
                                by: CGVector(dx: delta.processed.x, dy: delta.processed.y)
                            )
                        }
                    }
            }
        }
    }
}
