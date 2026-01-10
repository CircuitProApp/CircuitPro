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
                    canvasManager.environment.grid.spacing = spacing
                } label: {
                    Text(spacing.label)
                }
            }
        } label: {
            HStack(spacing: 2.5) {
                Text(canvasManager.environment.grid.spacing.label)
                    .font(.system(size: 12))
                Image(systemName: CircuitProSymbols.Generic.chevronDown)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 7, height: 7)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
