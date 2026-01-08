import CoreGraphics
import Foundation

struct Socket: Hashable {
    let id: UUID
    var offset: CGPoint

    init(id: UUID = UUID(), offset: CGPoint) {
        self.id = id
        self.offset = offset
    }
}
