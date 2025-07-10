//
//  ValidationStatus.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import SwiftUI

struct ValidationState: OptionSet {
    let rawValue: Int

    static let valid = ValidationState([])
    static let warning = ValidationState(rawValue: 1 << 0)
    static let error = ValidationState(rawValue: 1 << 1)
}

struct ValidationHighlightModifier: ViewModifier {
    let state: ValidationState

    @ViewBuilder
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 7.5)
                .stroke(strokeColor, style: strokeStyle)
                .animation(.default, value: state)
        )
    }

    private var strokeColor: Color {
        if state.contains(.error) {
            return .red
        } else if state.contains(.warning) {
            return .yellow
        } else {
            return .clear
        }
    }

    private var strokeStyle: StrokeStyle {
        if state.contains(.error) {
            return StrokeStyle(lineWidth: 2)
        } else if state.contains(.warning) {
            return StrokeStyle(lineWidth: 2, dash: [6])
        } else {
            return StrokeStyle(lineWidth: 0)
        }
    }
}

extension View {
    func validationStatus(_ state: ValidationState) -> some View {
        modifier(ValidationHighlightModifier(state: state))
    }
}
