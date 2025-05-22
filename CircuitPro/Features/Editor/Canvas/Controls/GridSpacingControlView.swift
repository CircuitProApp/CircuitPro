//
//  GridSpacingControlView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/17/25.
//

import SwiftUI

struct GridSpacingControlView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var body: some View {
        Menu {
            ForEach(GridSpacing.allCases, id: \.self) { spacing in
                Button {
                    canvasManager.gridSpacing = spacing
                } label: {
                    Text(spacing.label)
                }
            }
        } label: {
            HStack {
                Text(canvasManager.gridSpacing.label)
                Image(systemName: AppIcons.chevronDown)
                    .imageScale(.small)
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .fontWeight(.semibold)
        .directionalPadding(vertical: 7.5, horizontal: 10)
        .background(.ultraThinMaterial)
        .clipAndStroke(with: .capsule, strokeColor: .gray.opacity(0.3), lineWidth: 1)
    }
}
