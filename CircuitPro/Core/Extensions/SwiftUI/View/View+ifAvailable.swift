//
//  View+ifAvailable.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/17/25.
//

import SwiftUI

extension View {
    /// Conditionally applies a modifier when running on macOS 26.0 or newer.
    /// Note: Swift cannot express availability on closure parameters, so call sites
    /// must not reference 26-only APIs directly inside the closure.
    @ViewBuilder
    public func ifAvailable<Content: View>(
        _ modifier: (Self) -> Content
    ) -> some View {
        if #available(macOS 26.0, *) {
            modifier(self)
        } else {
            self
        }
    }

    /// Safely applies `backgroundExtensionEffect()` on macOS 26.0+.
    @ViewBuilder
    public func backgroundExtensionEffectIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }
}
