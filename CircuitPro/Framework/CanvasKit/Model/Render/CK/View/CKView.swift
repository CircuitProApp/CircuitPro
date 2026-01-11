import AppKit

protocol CKView {
    associatedtype Body: CKView
    @CKViewBuilder var body: Body { get }
    func _render(in context: RenderContext) -> [DrawingPrimitive]
}

extension Never: CKView {
    var body: Never {
        fatalError("Never has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        []
    }
}

extension CKView {
    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        body._render(in: context)
    }
}

private struct CKOpacityView: CKView {
    typealias Body = Never
    let content: AnyCKView
    let opacity: CGFloat

    var body: Never {
        fatalError("CKOpacityView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let value = opacity.clamped(to: 0...1)
        return content._render(in: context).map { $0.applyingOpacity(value) }
    }
}

extension CKView {
    func opacity(_ value: CGFloat) -> some CKView {
        CKOpacityView(content: AnyCKView(self), opacity: value)
    }
}

extension DrawingPrimitive {
    func applyingOpacity(_ opacity: CGFloat) -> DrawingPrimitive {
        switch self {
        case let .fill(path, color, rule, clipPath):
            return .fill(
                path: path,
                color: color.applyingOpacity(opacity),
                rule: rule,
                clipPath: clipPath
            )
        case let .stroke(path, color, lineWidth, lineCap, lineJoin, miterLimit, lineDash, clipPath):
            return .stroke(
                path: path,
                color: color.applyingOpacity(opacity),
                lineWidth: lineWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                lineDash: lineDash,
                clipPath: clipPath
            )
        }
    }
}
