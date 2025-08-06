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
                    canvasManager.environment.configuration.grid.spacing = spacing
                    print("[1] CONTROL VIEW: Grid spacing changed to: \(canvasManager.environment.configuration.grid.spacing )")
                } label: {
                    Text(spacing.label)
                }
            }
        } label: {
            HStack(spacing: 2.5) {
                Text(canvasManager.environment.configuration.grid.spacing.label)
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
