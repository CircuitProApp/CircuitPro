//
//  CanvasOverlayView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/11/25.
//

import SwiftUI

struct CanvasOverlayView<Toolbar: View>: View {

    private let toolbarBuilder: () -> Toolbar

    init(toolbar: @escaping () -> Toolbar) {
        self.toolbarBuilder = toolbar
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                toolbarBuilder()
            }
            Spacer()
            HStack {
               
        
                CanvasControlView()
                Spacer()
                GridSpacingControlView()
                ZoomControlView()
              
            }
        }
    }
}

extension CanvasOverlayView where Toolbar == EmptyView {
    init() {
        self.init {
            EmptyView()
        }
    }
}

#Preview {
    CanvasOverlayView()
}
