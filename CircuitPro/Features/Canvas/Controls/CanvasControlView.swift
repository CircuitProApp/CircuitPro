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
    
    var editorType: EditorType 

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
                Image(systemName: CircuitProSymbols.Canvas.crosshairs)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(canvasManager.crosshairsStyle != .hidden ? .blue : .secondary)
            }
            if editorType != .schematic {
                Button {
                    canvasManager.enableSnapping.toggle()
                } label: {
                    Image(systemName: CircuitProSymbols.Canvas.snapping)
                        .frame(width: 13, height: 13)
                        .foregroundStyle(canvasManager.enableSnapping ? .blue : .secondary)
                }
            }
            Button {
                canvasManager.enableAxesBackground.toggle()
            } label: {
                Image(systemName: CircuitProSymbols.Canvas.axesBackground)
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
                        CircuitProSymbols.Generic.checkmark : CircuitProSymbols.Canvas.dottedBackground
                    )
                    .symbolVariant(canvasManager.backgroundStyle == .grid ? .circle.fill : .none)
                    .labelStyle(.titleAndIcon)
                }
                Button {
                    canvasManager.backgroundStyle = .grid
                } label: {
                    Label(
                        "Grid Background",
                        systemImage: canvasManager.backgroundStyle == .grid ?
                        CircuitProSymbols.Generic.checkmark : CircuitProSymbols.Canvas.gridBackground
                    )
                    .symbolVariant(canvasManager.backgroundStyle == .grid ? .circle.fill : .none)
                    .labelStyle(.titleAndIcon)
                }
            } label: {
                Image(systemName: CircuitProSymbols.Canvas.backgroundType)
                    .frame(width: 13, height: 13)
            }
        }
        .buttonStyle(.plain)
    }
}
