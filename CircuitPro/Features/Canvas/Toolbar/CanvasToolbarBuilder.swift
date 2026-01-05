import SwiftUI

struct CanvasToolbarDivider {}

enum CanvasToolbarItem {
    case tool(CanvasTool)
    case divider
}

@resultBuilder
struct CanvasToolbarBuilder {
    static func buildExpression(_ tool: CanvasTool) -> [CanvasToolbarItem] {
        [.tool(tool)]
    }

    static func buildExpression(_ divider: CanvasToolbarDivider) -> [CanvasToolbarItem] {
        [.divider]
    }

    static func buildBlock(_ components: [CanvasToolbarItem]...) -> [CanvasToolbarItem] {
        components.flatMap { $0 }
    }

    static func buildOptional(_ component: [CanvasToolbarItem]?) -> [CanvasToolbarItem] {
        component ?? []
    }

    static func buildEither(first component: [CanvasToolbarItem]) -> [CanvasToolbarItem] {
        component
    }

    static func buildEither(second component: [CanvasToolbarItem]) -> [CanvasToolbarItem] {
        component
    }

    static func buildArray(_ components: [[CanvasToolbarItem]]) -> [CanvasToolbarItem] {
        components.flatMap { $0 }
    }
}
