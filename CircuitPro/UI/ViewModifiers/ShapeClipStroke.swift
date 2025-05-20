//
//  ViewModifiers.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//

import SwiftUI

struct ShapeClipStroke<S: Shape>: ViewModifier {
    let shape: S
    let strokeColor: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(shape)
            .overlay {
                shape
                    .stroke(strokeColor, lineWidth: lineWidth)
            }
    }
}

extension View {
    func clipAndStroke<S: Shape>(
        with shape: S,
        strokeColor: Color = .gray.opacity(0.3),
        lineWidth: CGFloat = 1
    ) -> some View {
        self.modifier(ShapeClipStroke(shape: shape, strokeColor: strokeColor, lineWidth: lineWidth))
    }
}
