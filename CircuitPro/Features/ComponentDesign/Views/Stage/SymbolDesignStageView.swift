//
//  SymbolDesignStageView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct SymbolDesignStageView: View {

    @Environment(\.componentDesignManager)
    private var componentDesignManager
    
    @Environment(CanvasManager.self)
    private var symbolCanvasManager

    var body: some View {
        StageContentView(
            left: { Color.clear },
            center: {
                SymbolDesignView()
                    .environment(symbolCanvasManager)
            },
            right: {
                if componentDesignManager.symbolElements.isNotEmpty {
                    PinEditorView()
                        .padding()
                } else {
                    Color.clear
                }
            }
        )
    }
}
