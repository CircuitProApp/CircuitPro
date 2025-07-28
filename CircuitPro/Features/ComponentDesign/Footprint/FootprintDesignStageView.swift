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
               FootprintElementListView()
                    .padding()
            },
            center: {
                FootprintDesignView()
                    .environment(footprintCanvasManager)
            },
            right: {
                if componentDesignManager.footprintElements.isNotEmpty {
                    FootprintPropertiesEditorView()
                        .padding()
                } else {
                    Color.clear
                }
            }
        )
    }
}
