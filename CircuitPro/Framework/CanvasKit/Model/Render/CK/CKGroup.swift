import AppKit

struct CKGroup: CKView {
    typealias Body = Never
    let children: [AnyCKView]
    static let empty = CKGroup()

    init(_ children: [AnyCKView] = []) {
        self.children = children
    }

    init(primitives: [DrawingPrimitive]) {
        self.children = primitives.map { AnyCKView($0.asCKView()) }
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

private extension DrawingPrimitive {
    func asCKView() -> some CKView {
        switch self {
        case let .fill(path, color, rule, clipPath):
            var view = CKPath(path: path).fill(color, rule: rule)
            if let clipPath {
                view = view.clip(clipPath)
            }
            return view
        case let .stroke(
            path,
            color,
            lineWidth,
            lineCap,
            lineJoin,
            miterLimit,
            lineDash,
            clipPath
        ):
            var view = CKPath(path: path)
                .stroke(color, width: lineWidth)
                .lineCap(lineCap)
                .lineJoin(lineJoin)
                .miterLimit(miterLimit)
            if let lineDash {
                view = view.lineDash(lineDash.map { CGFloat(truncating: $0) })
            }
            if let clipPath {
                view = view.clip(clipPath)
            }
            return view
        }
    }
}
