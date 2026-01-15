import AppKit

struct PinView: CKView {
    @CKContext var context
    @CKEnvironment var environment

    let pin: Pin

    var pinColor: CGColor {
        environment.schematicTheme.pinColor
    }

    var textColor: CGColor {
        environment.schematicTheme.textColor
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
                if pin.showLabel && pin.name.isNotEmpty {
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

    }
}

extension PinView: CKHitTestable {
    func hitTestPath(in context: RenderContext) -> CGPath {
        let base = CGMutablePath()
        base.move(to: .zero)
        base.addLine(to: CGPoint(x: pin.length, y: 0))
        let circleRect = CGRect(x: -5.0, y: -5.0, width: 10.0, height: 10.0)
        base.addPath(CGPath(ellipseIn: circleRect, transform: nil))
        guard !base.isEmpty else { return CGMutablePath() }
        let padding = 4.0 / max(context.magnification, 0.001)
        let strokeWidth = 1.0 + padding
        return base.copy(
            strokingWithWidth: strokeWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
    }
}
