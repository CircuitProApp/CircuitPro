import SwiftUI

extension Collection {
    var isNotEmpty: Bool {
        !isEmpty
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
