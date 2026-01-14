import Foundation

final class CanvasDragSession {
    private var storage: [AnyHashable: Any] = [:]

    func set<T>(_ value: T?, for key: AnyHashable) {
        storage[key] = value
    }

    func value<T>(for key: AnyHashable, as type: T.Type = T.self) -> T? {
        storage[key] as? T
    }
}
