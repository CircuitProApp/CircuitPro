import AppKit

struct DesignView: CKView {
    @CKContext var context
    @CanvasItems(Pin.self) var pins
    @CanvasItems(Pad.self) var pads
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
