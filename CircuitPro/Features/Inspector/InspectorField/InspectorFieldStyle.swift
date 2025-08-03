//
//  InspectorTextFieldStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

struct InspectorFieldStyle: ViewModifier {

    @Environment(\.inspectorFieldWidth)
    private var overrideWidth

    @FocusState private var isFocused: Bool

    let width: CGFloat?

    func body(content: Content) -> some View {
        let finalWidth = overrideWidth ?? width

        content
            .focused($isFocused)
            .if(finalWidth != nil) {
                $0.frame(width: finalWidth)
            }
            .textFieldStyle(.plain)
            .directionalPadding(vertical: 2.5, horizontal: 5)
            .background {
                if isFocused {
                    Color(NSColor.textBackgroundColor)
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .font(.callout)
            .clipAndStroke(with: .rect(cornerRadius: 5))
            .focusRing(isFocused, shape: .rect(cornerRadius: 6))
            .onTapGesture { isFocused = true }
            .onSubmit { isFocused = false }
    }
}

extension View {
    func inspectorField(width: CGFloat? = nil) -> some View {
        modifier(InspectorFieldStyle(width: width))
    }
}
