//
//  CanvasColorPickerView.swift
//  CircuitPro
//
//  Created by Codex on 12/29/25.
//

import SwiftUI

struct CanvasColorPickerView: View {
    let title: String
    @Binding var hex: String
    var showReset: Bool
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            if showReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
            }
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hex: hex) },
                    set: { hex = $0.toHexRGBA() }
                )
            )
            .labelsHidden()
        }
    }
}
