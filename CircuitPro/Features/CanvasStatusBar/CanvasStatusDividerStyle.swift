//
//  CanvasStatusDividerStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

struct CanvasStatusDividerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.quinary)
            .frame(height: 12)
    }
}

extension View {
    func canvasStatusDividerStyle() -> some View {
        modifier(CanvasStatusDividerStyle())
    }
}
