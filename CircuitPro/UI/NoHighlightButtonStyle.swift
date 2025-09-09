//
//  NoHighlightButtonStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/9/25.
//

import SwiftUI

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1) // ignore press opacity
            .scaleEffect(1) // prevent scaling
    }
}
