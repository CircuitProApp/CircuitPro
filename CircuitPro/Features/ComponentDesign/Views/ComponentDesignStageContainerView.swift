//
//  ComponentDesignStageContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct ComponentDesignStageContainerView: View {
    @Binding var currentStage: ComponentDesignStage

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    let symbolCanvasManager: CanvasManager
    let footprintCanvasManager: CanvasManager

    var body: some View {
        VStack {
            StageIndicatorView(
                currentStage: $currentStage,
                validationProvider: componentDesignManager.validationState
            )
            Spacer()
            switch currentStage {
            case .component:
                ComponentDetailStageView()
            case .symbol:
                SymbolDesignStageView()
                    .environment(symbolCanvasManager)
            case .footprint:
                FootprintDesignStageView()
                    .environment(footprintCanvasManager)
            }
            Spacer()
        }
    }
}
