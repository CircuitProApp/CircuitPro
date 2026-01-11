import AppKit

protocol CKView {
    associatedtype Body: CKView
    var body: Body { get }
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

struct CKEmpty: CKView {
    typealias Body = Never

    var body: Never {
        fatalError("CKEmpty has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        []
    }
}

struct AnyCKView: CKView {
    typealias Body = Never
    private let renderer: (RenderContext) -> [DrawingPrimitive]

    init<V: CKView>(_ view: V) {
        self.renderer = view._render
    }

    var body: Never {
        fatalError("AnyCKView has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        renderer(context)
    }
}

struct CKGroup: CKView {
    typealias Body = Never
    fileprivate let children: [AnyCKView]
    static let empty = CKGroup()

    init(_ children: [AnyCKView] = []) {
        self.children = children
    }

    init(@CKViewBuilder _ content: () -> CKGroup) {
        self = content()
    }

    var body: Never {
        fatalError("CKGroup has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        children.flatMap { $0._render(in: context) }
    }
}

struct CKPrimitives: CKView {
    typealias Body = Never
    private let renderer: (RenderContext) -> [DrawingPrimitive]

    init(_ renderer: @escaping (RenderContext) -> [DrawingPrimitive]) {
        self.renderer = renderer
    }

    var body: Never {
        fatalError("CKPrimitives has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        renderer(context)
    }
}

struct CKOpacity: CKView {
    typealias Body = Never
    let content: AnyCKView
    let opacity: CGFloat

    var body: Never {
        fatalError("CKOpacity has no body.")
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        let value = opacity.clamped(to: 0...1)
        return content._render(in: context).map { $0.applyingOpacity(value) }
    }
}

extension CKView {
    func opacity(_ value: CGFloat) -> CKOpacity {
        CKOpacity(content: AnyCKView(self), opacity: value)
    }
}

@resultBuilder
struct CKViewBuilder {
    static func buildBlock(_ components: CKGroup...) -> CKGroup {
        CKGroup(components.flatMap { $0.children })
    }

    static func buildExpression<V: CKView>(_ expression: V) -> CKGroup {
        CKGroup([AnyCKView(expression)])
    }

    static func buildExpression(_ expression: CKGroup) -> CKGroup {
        expression
    }

    static func buildOptional(_ component: CKGroup?) -> CKGroup {
        component ?? CKGroup()
    }

    static func buildEither(first component: CKGroup) -> CKGroup {
        component
    }

    static func buildEither(second component: CKGroup) -> CKGroup {
        component
    }

    static func buildArray(_ components: [CKGroup]) -> CKGroup {
        CKGroup(components.flatMap { $0.children })
    }
}

protocol CKPathProvider {
    func path(in context: RenderContext) -> CGPath
}

struct AnyCKPath: CKPathProvider {
    private let builder: (RenderContext) -> CGPath

    init(_ builder: @escaping (RenderContext) -> CGPath) {
        self.builder = builder
    }

    func path(in context: RenderContext) -> CGPath {
        builder(context)
    }
}

@resultBuilder
struct CKPathBuilder {
    static func buildBlock(_ components: [AnyCKPath]...) -> [AnyCKPath] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ expression: AnyCKPath) -> [AnyCKPath] {
        [expression]
    }

    static func buildExpression(_ expression: CKPathProvider) -> [AnyCKPath] {
        [AnyCKPath { context in
            expression.path(in: context)
        }]
    }

    static func buildOptional(_ component: [AnyCKPath]?) -> [AnyCKPath] {
        component ?? []
    }

    static func buildEither(first component: [AnyCKPath]) -> [AnyCKPath] {
        component
    }

    static func buildEither(second component: [AnyCKPath]) -> [AnyCKPath] {
        component
    }

    static func buildArray(_ components: [[AnyCKPath]]) -> [AnyCKPath] {
        components.flatMap { $0 }
    }
}

struct CKStyle {
    var position: CGPoint?
    var size: CGSize?
    var fillColor: CGColor?
    var strokeColor: CGColor?
    var strokeWidth: CGFloat = 1.0
    var lineCap: CAShapeLayerLineCap = .round
    var lineJoin: CAShapeLayerLineJoin = .round
    var miterLimit: CGFloat = 10
    var lineDash: [NSNumber]?
    var clipPath: CGPath?
    var halos: [CKHalo] = []
    var rotation: CGFloat = 0
}

struct CKHalo {
    var color: CGColor
    var width: CGFloat
}

protocol CKStyled {
    var style: CKStyle { get set }
}

protocol CKStyledPath: CKPathProvider, CKStyled, CKView {}

protocol CKShape: CKStyledPath {
    func shapePath() -> CGPath
}

extension CKStyled {
    func frame(width: CGFloat, height: CGFloat) -> Self {
        var copy = self
        copy.style.size = CGSize(width: width, height: height)
        return copy
    }

    func position(_ point: CGPoint) -> Self {
        var copy = self
        copy.style.position = point
        return copy
    }

    func position(x: CGFloat, y: CGFloat) -> Self {
        position(CGPoint(x: x, y: y))
    }

    func fill(_ color: CGColor) -> Self {
        var copy = self
        copy.style.fillColor = color
        return copy
    }

    func stroke(_ color: CGColor, width: CGFloat = 1.0) -> Self {
        var copy = self
        copy.style.strokeColor = color
        copy.style.strokeWidth = width
        return copy
    }

    func lineCap(_ lineCap: CAShapeLayerLineCap) -> Self {
        var copy = self
        copy.style.lineCap = lineCap
        return copy
    }

    func lineJoin(_ lineJoin: CAShapeLayerLineJoin) -> Self {
        var copy = self
        copy.style.lineJoin = lineJoin
        return copy
    }

    func miterLimit(_ limit: CGFloat) -> Self {
        var copy = self
        copy.style.miterLimit = limit
        return copy
    }

    func lineDash(_ pattern: [CGFloat]) -> Self {
        var copy = self
        copy.style.lineDash = pattern.map { NSNumber(value: Double($0)) }
        return copy
    }

    func halo(_ color: CGColor, width: CGFloat) -> Self {
        var copy = self
        copy.style.halos.append(CKHalo(color: color, width: width))
        return copy
    }

    func clip(to rect: CGRect) -> Self {
        self
    }

    func clip(_ path: CGPath) -> Self {
        self
    }

    func rotation(_ angle: CGFloat) -> Self {
        var copy = self
        copy.style.rotation = angle
        return copy
    }
}

extension CKStyledPath {
    var body: CKEmpty {
        CKEmpty()
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        var path = path(in: context)
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

extension CKShape {
    func path(in context: RenderContext) -> CGPath {
        shapePath()
    }
}

private func ckPrimitives(for path: CGPath, style: CKStyle) -> [DrawingPrimitive] {
    guard !path.isEmpty else { return [] }
    var primitives: [DrawingPrimitive] = []
    if !style.halos.isEmpty {
        for halo in style.halos where halo.width > 0 {
            primitives.append(
                .stroke(
                    path: path,
                    color: halo.color,
                    lineWidth: halo.width,
                    lineCap: style.lineCap,
                    lineJoin: style.lineJoin,
                    miterLimit: style.miterLimit,
                    lineDash: style.lineDash,
                    clipPath: style.clipPath
                )
            )
        }
    }
    if let fillColor = style.fillColor {
        primitives.append(.fill(path: path, color: fillColor, clipPath: style.clipPath))
    }
    if let strokeColor = style.strokeColor {
        primitives.append(
            .stroke(
                path: path,
                color: strokeColor,
                lineWidth: style.strokeWidth,
                lineCap: style.lineCap,
                lineJoin: style.lineJoin,
                miterLimit: style.miterLimit,
                lineDash: style.lineDash,
                clipPath: style.clipPath
            )
        )
    }
    return primitives
}

private extension DrawingPrimitive {
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
