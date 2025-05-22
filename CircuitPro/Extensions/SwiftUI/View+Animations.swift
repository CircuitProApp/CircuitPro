//
//  View+Animations.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.05.25.
//

import SwiftUI

extension View {
    func disableAnimations() -> some View {
        self.transaction { transaction in
            transaction.animation = nil
        }
    }
}

extension View {
    func enableAnimations(_ animation: Animation? = .default) -> some View {
        self.transaction { transaction in
            transaction.animation = animation
        }
    }
}
