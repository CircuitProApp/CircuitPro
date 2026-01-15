import AppKit

struct CKGroup: CKView {
    typealias Body = CKGroup
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

    var body: CKGroup {
        .empty
    }

    func _render(in context: RenderContext) -> [DrawingPrimitive] {
        children.enumerated().flatMap { index, child in
            context.render(child, index: index)
        }
    }

    func _paths(in context: RenderContext) -> [CGPath] {
        children.enumerated().flatMap { index, child in
            context.paths(child, index: index)
        }
    }
}

extension CKGroup: CKHitTestable {
    func hitTestPath(in context: RenderContext) -> CGPath {
        let merged = CGMutablePath()
        for (index, child) in children.enumerated() {
            let path = CKContextStorage.withViewScope(index: index) {
                if let hitTestPath = child.hitTestPath(in: context), !hitTestPath.isEmpty {
                    return hitTestPath
                }
                let paths = child._paths(in: context).filter { !$0.isEmpty }
                guard !paths.isEmpty else { return CGMutablePath() }
                let combined = CGMutablePath()
                for path in paths {
                    combined.addPath(path)
                }
                return combined
            }
            if !path.isEmpty {
                merged.addPath(path)
            }
        }
        return merged.isEmpty ? CGMutablePath() : merged
    }
}

private extension DrawingPrimitive {
    func asCKView() -> AnyCKView {
        switch self {
        case let .fill(path, color, rule, clipPath):
            var view = CKPath(path: path).fill(color, rule: rule)
            if let clipPath {
                view = view.clip(clipPath)
            }
            return AnyCKView(view)
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
            return AnyCKView(view)
        }
    }
}
