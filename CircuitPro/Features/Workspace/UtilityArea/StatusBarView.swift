//
//  StatusBarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct StatusBarView: View {

    var canvasManager: CanvasManager

    @Binding var showUtilityArea: Bool

    var body: some View {
        HStack {
            CanvasControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.leading, 4)
            Spacer()
            HStack {
                Text(String(format: "x: %.1f", canvasManager.relativeMousePosition.x))
                Text(String(format: "y: %.1f", canvasManager.relativeMousePosition.y))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Spacer()
            GridSpacingControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
            ZoomControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.trailing, 4)
            Button {
                withAnimation {
                    self.showUtilityArea.toggle()
                }
            } label: {
                Image(systemName: CircuitProSymbols.Workspace.toggleUtilityArea)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
                    .fontWeight(.light)
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    StatusBarView(canvasManager: .init(), showUtilityArea: .constant(true))
}
