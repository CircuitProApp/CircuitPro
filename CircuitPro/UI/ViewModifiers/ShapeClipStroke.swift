//
//  ShapeClipStroke.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//

import SwiftUI

struct ShapeClipStroke<IS: InsettableShape, SS: ShapeStyle>: ViewModifier {
    let shape: IS
    let strokeColor: SS
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
    func clipAndStroke<IS: InsettableShape, SS: ShapeStyle>(
        with shape: IS,
        strokeColor: SS = .stroleColor,
        lineWidth: CGFloat = 1
    ) -> some View {
        self.modifier(ShapeClipStroke(shape: shape, strokeColor: strokeColor, lineWidth: lineWidth))
    }
}
