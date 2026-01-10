import AppKit

struct CrosshairsRL: CKRenderLayer {

    @CKContext var context

    var position: CGPoint {
        context.processedMouseLocation ?? .zero
    }

    var color: CGColor {
        context.environment.canvasTheme.crosshairColor
    }

    var strokeWidth: CGFloat {
        1.0 / max(context.magnification, .ulpOfOne)
    }

    var crosshairsStyle: CrosshairsStyle {
        context.environment.crosshairsStyle
    }

    var body: CKLayer {
        switch crosshairsStyle {
        case .hidden:
            CKLayer.empty
        case .fullScreenLines:
            crosshairs(width: context.canvasBounds.width, height: context.canvasBounds.height)
        case .centeredCross:
            crosshairs(width: 20, height: 20)
        }
    }

    func crosshairs(width: CGFloat, height: CGFloat) -> CKPath {
        CKPath {
            CKLine(length: width, direction: .horizontal)
            CKLine(length: height, direction: .vertical)
        }
        .position(position)
        .stroke(color, width: strokeWidth)
    }
}
