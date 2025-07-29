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

            if validationState.contains(.error) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.white, .red)
            }
            if validationState.contains(.warning) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white, .yellow)
            }
        }
        .directionalPadding(vertical: 5, horizontal: 7.5)
        .font(.subheadline)
        .fontWeight(.semibold)
        .background(isSelected ? AnyShapeStyle(.blue.quaternary) : AnyShapeStyle(.clear))
        .foregroundStyle(isSelected ? .blue : .secondary)
        .clipShape(.capsule)
        .animation(.default, value: validationState)
    }
}
