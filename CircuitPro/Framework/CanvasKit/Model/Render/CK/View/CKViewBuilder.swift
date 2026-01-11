import AppKit

@resultBuilder
struct CKViewBuilder {
    static func buildBlock(_ component: Never) -> Never {
        component
    }

    static func buildBlock(_ components: CKGroup...) -> CKGroup {
        CKGroup(components.flatMap { $0.children })
    }

    static func buildExpression(_ expression: Never) -> Never {
        expression
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
