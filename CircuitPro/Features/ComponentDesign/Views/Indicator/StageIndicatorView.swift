//
//  StageIndicatorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/29/25.
//


import SwiftUI

struct StageIndicatorView: View {
    @Binding var currentStage: ComponentDesignStage
    var validationProvider: (ComponentDesignStage) -> ValidationState

    var body: some View {
        HStack {
            ForEach(ComponentDesignStage.allCases) { stage in
                StagePillButton(
                    stage: stage,
                    isSelected: currentStage == stage,
                    validationState: validationProvider(stage),
                    action: { currentStage = stage }
                )
                
                if stage != .footprint {
                    Image(systemName: CircuitProSymbols.Generic.chevronRight)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(5)
    }
}
