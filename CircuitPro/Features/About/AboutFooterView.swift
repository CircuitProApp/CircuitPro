//
//  AboutFooterView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 08.06.25.
//

import SwiftUI
import AboutWindow

struct AboutFooterView: View {
    var body: some View {
        FooterView(
            primaryView: {
                Link(destination: URL(string: "https://github.com/CircuitProApp/CircuitPro/blob/main/LICENSE.md")!) {
                    Text("MIT License")
                        .underline()
                }
                .focusable(false)
            },
            secondaryView: {
                Text("Copyright © 2025 Circuit Pro")
            }
        )
    }
}
