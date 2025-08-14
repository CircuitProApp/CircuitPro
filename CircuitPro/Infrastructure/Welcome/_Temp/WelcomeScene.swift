//
//  AppWindow.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI

struct WelcomeScene: Scene {
    var body: some Scene {
        Window("Welcome", id: "WelcomeWindow") {
            WelcomeRootView()
        }
        .defaultSize(width: 760, height: 540)
        .windowStyle(.hiddenTitleBar)
    }
}

