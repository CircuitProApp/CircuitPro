//
//  StageContentView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct StageContentView<Left: View, Center: View, Right: View>: View {

    let left: Left
    let center: Center
    let right: Right
    let width: CGFloat
    let height: CGFloat
    let sidebarWidth: CGFloat

    init(
        width: CGFloat = 800,
        height: CGFloat = 500,
        sidebarWidth: CGFloat = 325,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
        self.width = width
        self.height = height
        self.sidebarWidth = sidebarWidth
    }
    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: sidebarWidth, height: height)
                .zIndex(0)
            center.frame(width: width, height: height)
                .zIndex(1)
            right.frame(width: sidebarWidth, height: height)
                .zIndex(0)
        }
    }
}
