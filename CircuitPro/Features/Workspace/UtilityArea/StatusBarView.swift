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
            SnappingControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.leading, 4)
            Spacer()
          MouseLocationView()

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
