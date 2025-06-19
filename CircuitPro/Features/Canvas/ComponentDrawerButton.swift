//
//  ComponentDrawerButton.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/17/25.
//

import SwiftUI

struct ComponentDrawerButton: View {
    @Environment(CanvasManager.self)
    private var canvasManager
    var body: some View {
        Button {
            withAnimation {
                canvasManager.showComponentDrawer.toggle()
            }
        } label: {
            HStack {
                if !canvasManager.showComponentDrawer {
                    Image(systemName: AppIcons.trayFull)
                        .transition(.move(edge: .leading).combined(with: .blurReplace))
                }
                Text("Component Drawer")
                if canvasManager.showComponentDrawer {
                    Image(systemName: AppIcons.xmark)
                        .transition(.move(edge: .trailing).combined(with: .blurReplace))
                }
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .fontWeight(.semibold)
        .directionalPadding(vertical: 7.5, horizontal: 10)
        .background(.ultraThinMaterial)
        .clipAndStroke(with: .capsule, strokeColor: .gray.opacity(0.3), lineWidth: 1)
    }
}

#Preview {
    ComponentDrawerButton()
}
