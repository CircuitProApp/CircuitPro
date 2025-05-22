//
//  CanvasOverlayView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/11/25.
//
import SwiftUI

struct CanvasOverlayView<Toolbar: View>: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    let enableComponentDrawer: Bool
    private let toolbarBuilder: () -> Toolbar

    init(
        enableComponentDrawer: Bool = true,
        toolbar: @escaping () -> Toolbar
    ) {
        self.enableComponentDrawer = enableComponentDrawer
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
                ZoomControlView()
                GridSpacingControlView()

                if enableComponentDrawer {
                    Spacer()
                    ComponentDrawerButton()
                }

                Spacer()
                CanvasControlView()
            }

            if enableComponentDrawer, canvasManager.showComponentDrawer {
                ComponentDrawerView()
            }
        }
    }
}

extension CanvasOverlayView where Toolbar == EmptyView {
    init(enableComponentDrawer: Bool = true) {
        self.init(enableComponentDrawer: enableComponentDrawer) {
            EmptyView()
        }
    }
}

#Preview {
    CanvasOverlayView()
}
