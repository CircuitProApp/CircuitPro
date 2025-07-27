//
//  ComponentDetailStageView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct ComponentDetailStageView: View {
    var body: some View {
        StageContentView(
            left: { Color.clear },
            center: { ComponentDetailView() },
            right: { Color.clear }
        )
    }
}
