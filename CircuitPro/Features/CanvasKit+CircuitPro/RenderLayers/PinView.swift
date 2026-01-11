import AppKit

struct PinView: CKView {
    @CKContext var context

    let pin: Pin

    var pinColor: CGColor {
        context.environment.schematicTheme.pinColor
    }

    var textColor: CGColor {
        context.environment.schematicTheme.textColor
    }

    var showHalo: Bool {
        context.highlightedItemIDs.contains(pin.id) ||
            context.selectedItemIDs.contains(pin.id)
    }

    var isWest: Bool {
        pin.cardinalRotation == .west
    }

    var body: some CKView {
        CKGroup {
            CKGroup {
                CKLine(from: .zero, to: CGPoint(x: pin.length, y: 0))
                CKCircle(radius: 5.0)
            }
            .stroke(pinColor)

            CKGroup {
                if pin.showLabel {
                    CKText(pin.label, font: .systemFont(ofSize: 10), anchor: isWest ? .trailing : .leading)
                        .position(x: pin.length + 5, y: 0)
                        .rotation(isWest ? pin.rotation : .zero)
                }
                if pin.showNumber {
                    CKText(pin.number.description, font: .systemFont(ofSize: 9))
                        .position(x: (pin.length / 2) + 2.5, y: isWest ? -5 : 5)
                        .rotation(isWest ? pin.rotation : .zero)
                }
            }
            .fill(textColor)
        }
        .position(pin.position)
        .rotation(pin.rotation)
        .halo(showHalo ? pinColor.copy(alpha: 0.4) ?? .clear : .clear, width: 5.0)
    }
}
