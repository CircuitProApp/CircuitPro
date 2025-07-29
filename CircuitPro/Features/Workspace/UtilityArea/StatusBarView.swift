//
//  StatusBarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct StatusBarView: View {

    var canvasManager: CanvasManager
    var editorType: EditorType

    var body: some View {
        HStack {
            CanvasControlView(editorType: editorType)
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.leading, 4)
            Spacer()
            HStack {
                Text(String(format: "x: %.0f", canvasManager.mouseLocationInMM.x))
                Text(String(format: "y: %.0f", canvasManager.mouseLocationInMM.y))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Spacer()
            if editorType != .schematic {
                GridSpacingControlView()
                Divider()
                    .foregroundStyle(.quinary)
                    .frame(height: 12)
            }
            ZoomControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.trailing, 4)

        }
    }
}

#Preview {
    StatusBarView(canvasManager: .init(), editorType: .schematic)
}
