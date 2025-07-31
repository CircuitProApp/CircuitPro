//
//  FocusRingModifier.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//

import SwiftUI

struct FocusRingModifier<S: InsettableShape>: ViewModifier {
    let isFocused: Bool
    let shape: S

    @Environment(\.focusRingColor) private var fallbackRingColor

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .focusEffectDisabled()
                .padding(1)
                .background(
                    shape
                        .stroke(
                            isFocused
                                ? Color(nsColor: .keyboardFocusIndicatorColor)
                                : fallbackRingColor,
                            lineWidth: 3
                        )
                        .animation(.easeInOut(duration: 0.1), value: isFocused)
                )
        } else {
            content
        }
    }
}

extension View {
    func focusRing<S: InsettableShape>(_ isFocused: Bool, shape: S) -> some View {
        self.modifier(FocusRingModifier(isFocused: isFocused, shape: shape))
    }
}
