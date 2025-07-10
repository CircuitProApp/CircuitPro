import SwiftUI

struct StageIndicatorView: View {
    @Binding var currentStage: ComponentDesignStage
    var validationProvider: (ComponentDesignStage) -> ValidationState

    var body: some View {
        HStack {
            ForEach(ComponentDesignStage.allCases) { stage in
                StagePill(
                    stage: stage,
                    isSelected: currentStage == stage,
                    validationState: validationProvider(stage)
                )
                .onTapGesture { currentStage = stage }
                if stage != .footprint {
                    Image(systemName: CircuitProSymbols.Generic.chevronRight)
                        .imageScale(.large)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
    }
}
