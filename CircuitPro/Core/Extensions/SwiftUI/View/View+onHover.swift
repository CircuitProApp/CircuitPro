//
//  View+onHover.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

extension View {
    func onHover(_ isHovered: Binding<Bool>) -> some View {
        self.onHover { hovering in
            isHovered.wrappedValue = hovering
        }
    }
}

extension View {
    func onHoverToggle<T: Equatable>(_ binding: Binding<T?>, hoverValue: T) -> some View {
        self.onHover { isHovered in
            binding.wrappedValue = isHovered ? hoverValue : nil
        }
    }
}
