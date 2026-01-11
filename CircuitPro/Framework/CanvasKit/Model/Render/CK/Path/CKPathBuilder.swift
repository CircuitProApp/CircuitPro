import AppKit

@resultBuilder
struct CKPathBuilder {
    static func buildBlock(_ components: [AnyCKPathView]...) -> [AnyCKPathView] {
        components.flatMap { $0 }
    }

    static func buildExpression<V: CKPathView>(_ expression: V) -> [AnyCKPathView] {
        [AnyCKPathView(expression)]
    }

    static func buildExpression(_ expression: CGPath) -> [AnyCKPathView] {
        [AnyCKPathView(path: expression)]
    }

    static func buildOptional(_ component: [AnyCKPathView]?) -> [AnyCKPathView] {
        component ?? []
    }

    static func buildEither(first component: [AnyCKPathView]) -> [AnyCKPathView] {
        component
    }

    static func buildEither(second component: [AnyCKPathView]) -> [AnyCKPathView] {
        component
    }

    static func buildArray(_ components: [[AnyCKPathView]]) -> [AnyCKPathView] {
        components.flatMap { $0 }
    }
}
