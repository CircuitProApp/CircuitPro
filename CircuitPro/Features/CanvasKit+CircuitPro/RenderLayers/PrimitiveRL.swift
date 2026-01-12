import AppKit

struct PrimitiveRL: CKView {
    @CKContext var context
    @CanvasItems(Pin.self) var pins
    @CanvasItems(Pad.self) var pads

    var body: some CKView {
        let primitives = context.items.compactMap { $0 as? AnyCanvasPrimitive }
        let textItems = context.items.compactMap { $0 as? CircuitText.Definition }

        CKGroup {
            for primitive in primitives {
                PrimitiveView(primitive: primitive)
            }

            for pad in pads {
                PadView(pad: pad.value)
                    .hoverable(pad.id)
                    .selectable(pad.id)
                    .onDragGesture { delta in
                        pad.update { pad in
                            pad.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
            }

            for pin in pins {
                PinView(pin: pin.value)
                    .hoverable(pin.id)
                    .selectable(pin.id)
                    .onDragGesture { delta in
                        pin.update { pin in
                            pin.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
            }

            for text in textItems {
                DefinitionTextView(text: text)
            }
        }
    }
}
