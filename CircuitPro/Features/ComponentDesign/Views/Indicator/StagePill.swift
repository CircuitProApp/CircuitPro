//
//  StagePill.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

struct StagePillButton: View {

    @State private var isHovering = false

    let stage: ComponentDesignStage
    let isSelected: Bool
    let validationState: ValidationState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            
        }
        .buttonStyle(.plain)
        .directionalPadding(vertical: 5, horizontal: 7.5)
        .font(.subheadline)
        .fontWeight(.semibold)
        .background(backgroundStyle())
        .foregroundStyle(isSelected ? .blue : .secondary)
        .clipShape(.capsule)
        .onHover { hovering in
            self.isHovering = hovering
        }
        .animation(.default, value: validationState)
    }
    
    private func backgroundStyle() -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.blue.quaternary)
        } else if isHovering {
            return AnyShapeStyle(.primary.opacity(0.1))
        } else {
            return AnyShapeStyle(.clear)
        }
    }
}
