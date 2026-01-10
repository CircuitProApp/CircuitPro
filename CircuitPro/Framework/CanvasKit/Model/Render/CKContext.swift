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

enum CKContextStorage {
    static var current: RenderContext?
}
