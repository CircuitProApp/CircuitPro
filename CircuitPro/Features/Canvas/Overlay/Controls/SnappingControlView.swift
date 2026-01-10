//
//  SnappingControlView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/3/25.
//
import SwiftUI

struct SnappingControlView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var body: some View {
        Button {
            canvasManager.environment.snapping.isEnabled.toggle()
        } label: {
            Image(systemName: CircuitProSymbols.Canvas.snapping)
                .frame(width: 13, height: 13)
                .foregroundStyle(canvasManager.environment.snapping.isEnabled ? .blue : .secondary)
        }
        .buttonStyle(.plain)
    }
}
