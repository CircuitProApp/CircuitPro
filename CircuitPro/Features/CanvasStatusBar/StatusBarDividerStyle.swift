//
//  StatusBarDividerStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

struct StatusBarDividerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.quinary)
            .frame(height: 12)
    }
}

extension View {
    func statusBardividerStyle() -> some View {
        modifier(StatusBarDividerStyle())
    }
}
