//
//  LibraryPanelModifier.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct LibraryPanelModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shouldShow in
                if shouldShow {
                    LibraryPanelManager.show {
                        self.isPresented = false
                    }
                } else {
                    LibraryPanelManager.hide()
                }
            }
    }
}

extension View {
    func libraryPanel(isPresented: Binding<Bool>) -> some View {
        self.modifier(LibraryPanelModifier(isPresented: isPresented))
    }
}
