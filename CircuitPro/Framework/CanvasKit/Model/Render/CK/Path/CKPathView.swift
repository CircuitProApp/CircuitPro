import AppKit

protocol CKPathView: CKView, CKHitTestable {
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

    func _paths(in context: RenderContext) -> [CGPath] {
        let path = self.path(in: context, style: defaultStyle)
        return path.isEmpty ? [] : [path]
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
        if style.rotation != 0 {
            let pivot = style.position ?? .zero
            var transform = CGAffineTransform(
                translationX: pivot.x,
                y: pivot.y
            )
            .rotated(by: style.rotation)
            .translatedBy(x: -pivot.x, y: -pivot.y)
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
        if self.style.rotation != 0 {
            let pivot = self.style.position ?? .zero
            var transform = CGAffineTransform(
                translationX: pivot.x,
                y: pivot.y
            )
            .rotated(by: self.style.rotation)
            .translatedBy(x: -pivot.x, y: -pivot.y)
            path = path.copy(using: &transform) ?? path
        }
        return path
    }
}
