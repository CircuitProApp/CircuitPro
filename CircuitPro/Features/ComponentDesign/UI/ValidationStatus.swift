//
//  ValidationStatus.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

enum ValidationState {
    case valid, warning, error
}

struct ValidationHighlightModifier: ViewModifier {
    let state: ValidationState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 7.5)
                .stroke(strokeColor, style: strokeStyle)
        )
    }

    private var strokeColor: Color {
        switch state {
        case .valid:
            return .clear
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }

    private var strokeStyle: StrokeStyle {
        switch state {
        case .valid:
            return StrokeStyle(lineWidth: 0)
        case .warning:
            return StrokeStyle(lineWidth: 2, dash: [6])
        case .error:
            return StrokeStyle(lineWidth: 2)
        }
    }
}

extension View {
    func validationStatus(_ state: ValidationState) -> some View {
        modifier(ValidationHighlightModifier(state: state))
    }
}
