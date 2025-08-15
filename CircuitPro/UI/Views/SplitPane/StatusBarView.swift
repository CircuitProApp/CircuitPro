//
//  StatusBarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/15/25.
//

import SwiftUI

/// A view that arranges content into three horizontal sections: leading, center, and trailing.
/// The center content is guaranteed to be perfectly centered within the view's bounds.
struct StatusBarView<Leading: View, Center: View, Trailing: View>: View {

    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 12.5) {
                leading
                Spacer()
                trailing
            }
            .padding(.horizontal, 12.5)
            center
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
