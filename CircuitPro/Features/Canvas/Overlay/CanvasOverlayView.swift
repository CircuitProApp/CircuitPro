//
//  CanvasOverlayView.swift
//  CircuitPro
//
//  Created by George Tchelidze on 1/4/26.
//

import SwiftUI

struct CanvasOverlayView<Toolbar: View, Status: View>: View {
    
    @ViewBuilder
    var toolbar: Toolbar
    @ViewBuilder
    var status: Status
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            toolbar
            Spacer()
            status
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

