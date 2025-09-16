import SwiftUI

// A compatibility wrapper that only references the new API inside
// an availability-gated scope, preventing compile-time availability errors.
extension View {
    @ViewBuilder
    func backgroundExtensionEffectCompat() -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }
}
