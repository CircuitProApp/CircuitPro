import AppKit

struct SymbolView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    let component: ComponentInstance

    var showHalo: Bool {
        context.highlightedItemIDs.contains(component.id) ||
            context.selectedItemIDs.contains(component.id)
    }

    var bodyColor: CKColor {
        CKColor(environment.schematicTheme.symbolColor)
    }

    var body: some CKView {
        let symbol = component.symbolInstance
        CKGroup {
            if let definition = symbol.definition {
                for primitive in definition.primitives {
                    PrimitiveView(primitive: primitive, isEditable: false)
                        .color(bodyColor)
                }
                for pin in definition.pins {
                    PinView(pin: pin)
                }
            }

            for text in symbol.resolvedItems where text.isVisible {
                AnchoredTextView(
                    text: text,
                    id: text.id,
                    display: { resolved in
                        component.displayString(for: resolved, target: .symbol)
                    },
                    onUpdate: { updated in
                        component.apply(updated, for: .symbol)
                    }
                )
            }
        }
        .position(symbol.position)
        .rotation(symbol.rotation)
        .halo(showHalo ? bodyColor.haloOpacity() : .clear, width: 5)
    }
}
