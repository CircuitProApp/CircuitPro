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
                CKGroup {
                    for primitive in definition.primitives {
                        PrimitiveView(primitive: primitive, isEditable: false)
                            .color(bodyColor)
                    }
                    for pin in definition.pins {
                        PinView(pin: pin)
                    }
                }
                .halo(showHalo ? bodyColor.haloOpacity() : .clear, width: 5)
                .hoverable(component.id)
                .selectable(component.id)
                .onDragGesture { delta in
                    context.update(component) { component in
                        component.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                    }
                }
            }

            for text in symbol.resolvedItems where text.isVisible {
                AnchoredTextView(
                    text: text,
                    id: CanvasTextID.makeID(
                        for: text.source,
                        ownerID: component.id,
                        fallback: text.id
                    ),
                    isParentHighlighted: showHalo,
                    display: { resolved in
                        component.displayString(for: resolved, target: .symbol)
                    },
                    onUpdate: { updated in
                        context.update(component) { component in
                            var overrides = component.symbolInstance.textOverrides
                            var instances = component.symbolInstance.textInstances
                            updated.apply(toOverrides: &overrides, andInstances: &instances)
                            component.symbolInstance.textOverrides = overrides
                            component.symbolInstance.textInstances = instances
                        }
                    }
                )
            }
        }
        .position(symbol.position)
        .rotation(symbol.rotation)
    }
}
