//
//  MouseLocationView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

struct MouseLocationView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "x: %.0f", canvasManager.mouseLocationInMM.x))
            Text(String(format: "y: %.0f", canvasManager.mouseLocationInMM.y))
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}
