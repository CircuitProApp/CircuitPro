import AppKit

struct CrosshairsView: CKView {

    @CKContext var context
    @CKEnvironment var environment

    var position: CGPoint {
        environment.processedMouseLocation ?? .zero
    }

    var color: CGColor {
        environment.canvasTheme.crosshairColor
    }

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

    var crosshairsStyle: CrosshairsStyle {
        environment.crosshairsStyle
    }

    var body: some CKView {
        switch crosshairsStyle {
        case .centeredCross:
            crosshairs(width: 20, height: 20)
        case .fullScreenLines:
            crosshairs(width: context.canvasBounds.width, height: context.canvasBounds.height)
        case .hidden:
            CKEmpty()
        }
    }

    private func crosshairs(width: CGFloat, height: CGFloat) -> some CKView {
        CKGroup {
            CKLine(length: width, direction: .horizontal)
            CKLine(length: height, direction: .vertical)
        }
        .position(position)
        .stroke(color, width: strokeWidth)
    }
}
