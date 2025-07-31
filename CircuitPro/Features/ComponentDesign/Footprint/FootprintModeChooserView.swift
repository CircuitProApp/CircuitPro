//
//  FootprintModeChooserView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//


import SwiftUI

// 2. New View for footprint mode selection
struct FootprintModeChooserView: View {
    @Environment(ComponentDesignManager.self) private var manager

    var body: some View {
        HStack {
            ForEach(FootprintStageMode.allCases) { mode in
                Button(action: { manager.footprintMode = mode }) {
                    Text(mode.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(manager.footprintMode == mode ? .white : .primary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background {
                             if manager.footprintMode == mode {
                                Capsule(style: .continuous).fill(.blue)
                             } else {
                                Capsule(style: .continuous).fill(.primary.opacity(0.1))
                             }
                        }
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
            }
        }
        .padding(4)
    }
}
