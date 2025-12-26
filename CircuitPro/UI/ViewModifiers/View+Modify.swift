import SwiftUI

extension View {
    /// A helper to apply modifiers conditionally or handle OS-specific APIs.
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}
