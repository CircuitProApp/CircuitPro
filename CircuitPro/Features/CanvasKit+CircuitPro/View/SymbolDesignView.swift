import AppKit

struct SymbolDesignView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CanvasItems(Pin.self) var pins
    @CanvasItems(AnyCanvasPrimitive.self) var primitives
    @CanvasItems(CircuitText.Definition.self) var texts

    var body: some CKView {
        CKGroup {
            for primitive in primitives {
                PrimitiveView(primitive: primitive.value, isEditable: true)
                   .hoverable(primitive.id)
                   .selectable(primitive.id)
                   .onDragGesture { delta in
                       primitive.update { primitive in
                           primitive.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                       }
                   }
            }

            for pin in pins {
                let showHalo = context.highlightedItemIDs.contains(pin.id) ||
                    context.selectedItemIDs.contains(pin.id)
                let pinColor = environment.schematicTheme.pinColor
                PinView(pin: pin.value)
                    .hoverable(pin.id)
                    .selectable(pin.id)
                    .onDragGesture { delta in
                        pin.update { pin in
                            pin.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
                    .halo(showHalo ? pinColor.copy(alpha: 0.4) ?? .clear : .clear, width: 5.0)
            }

            for text in texts {
                TextView(text: text.value)
                    .hoverable(text.id)
                    .selectable(text.id)
                    .onDragGesture { delta in
                        text.update { text in
                            text.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
            }
        }
    }
}
