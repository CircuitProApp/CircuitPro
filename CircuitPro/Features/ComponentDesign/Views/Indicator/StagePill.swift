//
//  StagePill.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

struct StagePill: View {
    
    let stage: ComponentDesignStage
    let isSelected: Bool
    let validationState: ValidationState

    var body: some View {
        HStack {
            Text(stage.label)

            switch validationState {
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.white, .red)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white, .yellow)
            case .valid:
                EmptyView()
            }
        }
        .padding(10)
        .font(.headline)
        .background(isSelected ? .blue : .clear)
        .foregroundStyle(isSelected ? .white : .secondary)
        .clipShape(.capsule)
        .animation(.default, value: validationState)
    }
}
