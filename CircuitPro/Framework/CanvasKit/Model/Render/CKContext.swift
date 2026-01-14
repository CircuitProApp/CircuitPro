import AppKit

@propertyWrapper
struct CKContext {
    var wrappedValue: RenderContext {
        guard let context = CKContextStorage.current else {
            fatalError("CKContext accessed outside of render update.")
        }
        return context
    }
}

@propertyWrapper
struct CKEnvironment {
    var wrappedValue: CanvasEnvironmentValues {
        guard let context = CKContextStorage.current else {
            fatalError("CKEnvironment accessed outside of render update.")
        }
        return context.environment
    }
}

enum CKContextStorage {
    static var current: RenderContext?
}
