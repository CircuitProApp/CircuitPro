import AppKit

protocol CKPathView: CKView {
    func path(in context: RenderContext, style: CKStyle) -> CGPath
    var defaultStyle: CKStyle { get }
}

extension CKPathView {
    var defaultStyle: CKStyle { CKStyle() }

    var body: Never {
        fatalError("CKPathView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        CKStyled(base: self, style: defaultStyle)._render(in: context)
    }
}

struct CKStyled<Base: CKPathView>: CKView {
    typealias Body = Never
    let base: Base
    var style: CKStyle

    var body: Never {
        fatalError("CKStyled has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        var path = base.path(in: context, style: style)
        if path.isEmpty {
            return []
        }
        if let position = style.position, style.rotation != 0 {
            var transform = CGAffineTransform(
                translationX: position.x,
                y: position.y
            )
            .rotated(by: style.rotation)
            .translatedBy(x: -position.x, y: -position.y)
            path = path.copy(using: &transform) ?? path
        }
        return ckPrimitives(for: path, style: style)
    }
}

extension CKStyled: CKPathView where Base: CKPathView {
    var defaultStyle: CKStyle { style }

    func path(in context: RenderContext, style: CKStyle) -> CGPath {
        var path = base.path(in: context, style: self.style)
        if path.isEmpty {
            return path
        }
        if let position = self.style.position, self.style.rotation != 0 {
            var transform = CGAffineTransform(
                translationX: position.x,
                y: position.y
            )
            .rotated(by: self.style.rotation)
            .translatedBy(x: -position.x, y: -position.y)
            path = path.copy(using: &transform) ?? path
        }
        return path
    }
}
