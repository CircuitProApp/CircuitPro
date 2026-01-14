import AppKit

struct SymbolDesignView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKContext(\.items, as: Pin.self) var pins
    @CKContext(\.items, as: AnyCanvasPrimitive.self) var primitives
    @CKContext(\.items, as: CircuitText.Definition.self) var texts

    var bodyColor: CKColor {
        CKColor(environment.schematicTheme.symbolColor)
    }

    var body: some CKView {
        CKGroup {
            for primitive in primitives {
                PrimitiveView(primitive: primitive, isEditable: true)
                    .hoverable(primitive.id)
                    .selectable(primitive.id)
                    .onDragGesture { delta in
                        context.update(primitive) { primitive in
                            primitive.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
                    .color(bodyColor)
            }

            for pin in pins {
                let showHalo = context.highlightedItemIDs.contains(pin.id) ||
                    context.selectedItemIDs.contains(pin.id)
                let pinColor = environment.schematicTheme.pinColor
                PinView(pin: pin)
                    .hoverable(pin.id)
                    .selectable(pin.id)
                    .onDragGesture { delta in
                        context.update(pin) { pin in
                            pin.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
                    .halo(showHalo ? CKColor(pinColor).haloOpacity() : .clear, width: 5.0)
            }

            for text in texts {
                TextView(text: text)
                    .hoverable(text.id)
                    .selectable(text.id)
                    .onDragGesture { delta in
                        context.update(text) { text in
                            text.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
            }
        }
    }
}
