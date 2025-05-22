//
//  DirectionalPadding.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/6/25.
//

import SwiftUI

struct DirectionalPadding: ViewModifier {
    var vertical: CGFloat
    var horizontal: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.vertical, vertical)
            .padding(.horizontal, horizontal)
    }
}

extension View {
    func directionalPadding(vertical: CGFloat, horizontal: CGFloat) -> some View {
        self.modifier(DirectionalPadding(vertical: vertical, horizontal: horizontal))
    }
}
