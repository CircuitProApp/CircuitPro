//
//  AboutWindowScene.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 08.06.25.
//

import SwiftUI
import AboutWindow

struct AboutWindowScene: Scene {
    var body: some Scene {
        AboutWindow(
            actions: {},
            footer: {
                FooterView(
                    primaryView: {
                        Link(destination: URL(string: "https://github.com/CircuitProApp/CircuitPro/blob/main/LICENSE.md")!) {
                            Text("BSL‑1.1 License")
                                .underline()
                        }
                        .focusable(false)
                    },
                    secondaryView: {
                        Text("Copyright © 2025 Circuit Pro")
                    }
                )
            }
        )
    }
}
