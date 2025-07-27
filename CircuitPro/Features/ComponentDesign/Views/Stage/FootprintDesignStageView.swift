//
//  FootprintDesignStageView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct FootprintDesignStageView: View {
    @Environment(\.componentDesignManager)
    private var componentDesignManager

    @Environment(CanvasManager.self)
    private var footprintCanvasManager

    var body: some View {
        StageContentView(
            left: {
                LayerTypeListView()
                    .transition(.move(edge: .leading).combined(with: .blurReplace))
                    .padding()
            },
            center: {
                FootprintDesignView()
                    .environment(footprintCanvasManager)
            },
            right: {
                if componentDesignManager.pads.isNotEmpty {
                    PadEditorView()
                        .transition(.move(edge: .trailing).combined(with: .blurReplace))
                        .padding()
                } else {
                    Color.clear
                }
            }
        )
    }
}
