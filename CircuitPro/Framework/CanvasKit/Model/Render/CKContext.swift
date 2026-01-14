import AppKit

@propertyWrapper
final class CKContext<Value> {
    private var cached: Value?
    private let getter: (RenderContext) -> Value

    init(_ keyPath: KeyPath<RenderContext, Value> = \.self) {
        self.getter = { $0[keyPath: keyPath] }
    }

    init<T: CanvasItem>(
        _ keyPath: KeyPath<RenderContext, [any CanvasItem]> = \.items,
        as type: T.Type
    ) where Value == [T] {
        self.getter = { context in
            context[keyPath: keyPath].compactMap { $0 as? T }
        }
    }

    var wrappedValue: Value {
        if let context = CKContextStorage.current ?? CKContextStorage.last {
            let value = getter(context)
            cached = value
            return value
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
        if let environment = CKContextStorage.environment ?? CKContextStorage.lastEnvironment {
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
    private var cachedKeyIsFallback = false
    private let initialValue: Value
    private let fallbackKey: CKViewStateKey

    init(wrappedValue: Value) {
        self.initialValue = wrappedValue
        self.fallbackKey = CKViewStateKey(
            path: [-1],
            index: CKContextStorage.nextFallbackIndex()
        )
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
        if let cachedKey, !cachedKeyIsFallback {
            return cachedKey
        }
        if let key = CKContextStorage.nextStateKey() {
            if let cachedKey, cachedKeyIsFallback,
               let store = CKContextStorage.stateStore,
               let value: Value = store.value(for: cachedKey) {
                store.set(value, for: key)
            }
            cachedKey = key
            cachedKeyIsFallback = false
            return key
        }
        if let cachedKey {
            return cachedKey
        }
        cachedKey = fallbackKey
        cachedKeyIsFallback = true
        return fallbackKey
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
    static var environment: CanvasEnvironmentValues?
    static var lastEnvironment: CanvasEnvironmentValues?

    private static var viewPath: [Int] = []
    private static var stateIndices: [Int] = []
    private static var fallbackSeed: Int = 0

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

    static func nextFallbackIndex() -> Int {
        let index = fallbackSeed
        fallbackSeed += 1
        return index
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
