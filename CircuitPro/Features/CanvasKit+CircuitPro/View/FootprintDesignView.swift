import AppKit

struct FootprintDesignView: CKView {
    @CKContext var context
    @CKEnvironment var environment
    @CKContext(\.items, as: Pad.self) var pads
    @CKContext(\.items, as: AnyCanvasPrimitive.self) var primitives
    @CKContext(\.items, as: CircuitText.Definition.self) var texts

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
            }

            for pad in pads {
                PadView(pad: pad)
                    .hoverable(pad.id)
                    .selectable(pad.id)
                    .onDragGesture { delta in
                        context.update(pad) { pad in
                            pad.translate(by: CGVector(dx: delta.processed.x, dy: delta.processed.y))
                        }
                    }
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
