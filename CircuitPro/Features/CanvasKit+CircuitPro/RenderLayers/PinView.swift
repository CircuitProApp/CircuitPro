import AppKit

struct PinView: CKView {
    @CKContext var context

    let pin: Pin

    var color: CGColor {
        context.environment.schematicTheme.pinColor
    }

    var isSelected: Bool {
        context.highlightedItemIDs.contains(pin.id)
    }

    var body: some CKView {

        CKPath {
            CKLine(from: .zero, to: CGPoint(x: pin.length, y: 0))
            CKCircle(radius: 5.0)

            if pin.showLabel {
                CKText(pin.label, font: .systemFont(ofSize: 11))
            }

            if pin.showNumber {
                CKText(pin.number.description, font: .systemFont(ofSize: 11))
            }

        }
        .position(pin.position)
        .rotation(pin.rotation)
        .stroke(color)
        .halo(isSelected ? color.copy(alpha: 0.4) ?? .clear : .clear, width: 5.0)

    }
}
