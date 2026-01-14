import SwiftUI

@dynamicMemberLookup
final class CanvasItemRef<T: CanvasItem> {
    let id: UUID
    private let getValue: () -> T?
    private let setValue: (T) -> Void

    init(id: UUID, get: @escaping () -> T?, set: @escaping (T) -> Void) {
        self.id = id
        self.getValue = get
        self.setValue = set
    }

    var value: T {
        guard let value = getValue() else {
            fatalError("Canvas item no longer exists.")
        }
        return value
    }

    subscript<Value>(dynamicMember keyPath: WritableKeyPath<T, Value>) -> Value {
        get {
            value[keyPath: keyPath]
        }
        set {
            var item = value
            item[keyPath: keyPath] = newValue
            setValue(item)
        }
    }

    func update(_ block: (inout T) -> Void) {
        var item = value
        block(&item)
        setValue(item)
    }
}

@propertyWrapper
struct CanvasItems<T: CanvasItem> {
    init(_ type: T.Type) {}

    var wrappedValue: [CanvasItemRef<T>] {
        guard let context = CKContextStorage.current else {
            fatalError("CanvasItems accessed outside of render update.")
        }

        let itemsBinding = context.itemsBinding
        let snapshot = context.items.compactMap { $0 as? T }

        return snapshot.map { item in
            let id = item.id
            return CanvasItemRef(
                id: id,
                get: {
                    if let itemsBinding,
                       let current = itemsBinding.wrappedValue.first(where: { $0.id == id }) as? T {
                        return current
                    }
                    return item
                },
                set: { updated in
                    guard let itemsBinding else { return }
                    var items = itemsBinding.wrappedValue
                    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
                    items[index] = updated
                    itemsBinding.wrappedValue = items
                }
            )
        }
    }
}
