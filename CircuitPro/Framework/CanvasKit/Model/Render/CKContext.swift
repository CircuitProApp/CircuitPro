import AppKit

@propertyWrapper
final class CKContext {
    private var cached: RenderContext?

    var wrappedValue: RenderContext {
        if let context = CKContextStorage.current ?? CKContextStorage.last {
            cached = context
            return context
        }
        if let cached {
            return cached
        }
        fatalError("CKContext accessed outside of render update.")
    }
}

@propertyWrapper
final class CKEnvironment {
    private var cached: CanvasEnvironmentValues?

    var wrappedValue: CanvasEnvironmentValues {
        if let context = CKContextStorage.current ?? CKContextStorage.last {
            let environment = context.environment
            cached = environment
            return environment
        }
        if let cached {
            return cached
        }
        fatalError("CKEnvironment accessed outside of render update.")
    }
}

@propertyWrapper
final class CKState<Value> {
    private var cachedKey: CKViewStateKey?
    private let initialValue: Value

    init(wrappedValue: Value) {
        self.initialValue = wrappedValue
    }

    var wrappedValue: Value {
        get {
            let key = resolveKey()
            guard let store = CKContextStorage.stateStore else {
                fatalError("CKState accessed outside of render update.")
            }
            if let value: Value = store.value(for: key) {
                return value
            }
            store.set(initialValue, for: key)
            return initialValue
        }
        set {
            let key = resolveKey()
            guard let store = CKContextStorage.stateStore else {
                fatalError("CKState accessed outside of render update.")
            }
            store.set(newValue, for: key)
        }
    }

    private func resolveKey() -> CKViewStateKey {
        if let cachedKey {
            return cachedKey
        }
        guard let key = CKContextStorage.nextStateKey() else {
            fatalError("CKState accessed outside of render update.")
        }
        cachedKey = key
        return key
    }
}

protocol CKStateToken: AnyObject {
    func _ckPrepareKey()
}

extension CKState: CKStateToken {
    func _ckPrepareKey() {
        _ = resolveKey()
    }
}

enum CKContextStorage {
    static var current: RenderContext?
    static var last: RenderContext?
    static var stateStore: CKStateStore?

    private static var viewPath: [Int] = []
    private static var stateIndices: [Int] = []

    static func resetViewScope() {
        viewPath = []
        stateIndices = []
    }

    static func withViewScope<T>(index: Int, _ action: () -> T) -> T {
        viewPath.append(index)
        stateIndices.append(0)
        defer {
            _ = stateIndices.popLast()
            _ = viewPath.popLast()
        }
        return action()
    }

    static func nextStateKey() -> CKViewStateKey? {
        guard !viewPath.isEmpty else { return nil }
        let index = stateIndices[stateIndices.count - 1]
        stateIndices[stateIndices.count - 1] = index + 1
        return CKViewStateKey(path: viewPath, index: index)
    }
}

enum CKStateRegistry {
    static func prepare<V: CKView>(_ view: V) {
        let mirror = Mirror(reflecting: view)
        for child in mirror.children {
            if let token = child.value as? CKStateToken {
                token._ckPrepareKey()
            }
        }
    }
}

struct CKViewStateKey: Hashable {
    let path: [Int]
    let index: Int
}

final class CKStateStore {
    private var storage: [CKViewStateKey: Any] = [:]

    func value<T>(for key: CKViewStateKey) -> T? {
        storage[key] as? T
    }

    func set<T>(_ value: T, for key: CKViewStateKey) {
        storage[key] = value
    }
}
