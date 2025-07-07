//
//  CanvasControlView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/3/25.
//
import SwiftUI

struct CanvasControlView: View {

    @Environment(CanvasManager.self)
    private var canvasManager

    var body: some View {
        HStack(spacing: 15) {
            Menu {
                ForEach(CrosshairsStyle.allCases) { style in
                    Button {
                        canvasManager.crosshairsStyle = style
                    } label: {
                        Text(style.label)
                    }
                }
            } label: {
                Image(systemName: AppIcons.crosshairs)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(canvasManager.crosshairsStyle != .hidden ? .blue : .secondary)
            }
            Button {
                canvasManager.enableSnapping.toggle()
            } label: {
                Image(systemName: AppIcons.snapping)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(canvasManager.enableSnapping ? .blue : .secondary)
            }

            Button {
                canvasManager.enableAxesBackground.toggle()
            } label: {
                Image(systemName: AppIcons.axesBackground)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(canvasManager.enableAxesBackground ? .blue : .secondary)
            }

            Menu {
                Button {
                    canvasManager.backgroundStyle = .dotted
                } label: {
                    Label(
                        "Dotted Background",
                        systemImage: canvasManager.backgroundStyle == .dotted ?
                        AppIcons.checkmarkCircleFill : AppIcons.dottedBackground
                    )
                    .labelStyle(.titleAndIcon)
                }
                Button {
                    canvasManager.backgroundStyle = .grid
                } label: {
                    Label(
                        "Grid Background",
                        systemImage: canvasManager.backgroundStyle == .grid ?
                        AppIcons.checkmarkCircleFill : AppIcons.gridBackground
                    )
                    .labelStyle(.titleAndIcon)
                }
            } label: {
                Image(systemName: AppIcons.backgroundType)
                    .frame(width: 13, height: 13)
            }
        }
        .buttonStyle(.plain)
    }
}
