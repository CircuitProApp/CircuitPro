//
//  FocusRingColorKey.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/31/25.
//

import SwiftUI

private struct FocusRingColorKey: EnvironmentKey {
    static let defaultValue: Color = .clear
}

extension EnvironmentValues {
    var focusRingColor: Color {
        get { self[FocusRingColorKey.self] }
        set { self[FocusRingColorKey.self] = newValue }
    }
}
