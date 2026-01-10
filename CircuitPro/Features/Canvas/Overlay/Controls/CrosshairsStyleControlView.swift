//
//  CrosshairsStyleControlView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

struct CrosshairsStyleControlView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var body: some View {
        Menu {
            ForEach(CrosshairsStyle.allCases) { style in
                Button {
                    canvasManager.environment.crosshairsStyle = style
                } label: {
                    Text(style.label)
                }
            }
        } label: {
            Image(systemName: CircuitProSymbols.Canvas.crosshairs)
                .frame(width: 13, height: 13)
                .foregroundStyle(canvasManager.environment.crosshairsStyle != .hidden ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}
