import Foundation

extension RenderContext {
    func update(_ id: UUID, _ update: (inout AnyCanvasPrimitive) -> Void) {
        updateItem(id, as: AnyCanvasPrimitive.self, update)
    }
}
