//
//  CanvasControlView.swift
//  Electron
//
//  Created by Giorgi Tchelidze on 4/3/25.
//
import SwiftUI

struct CanvasControlView: View {
    
    @Environment(CanvasManager.self) private var canvasManager
    
    var body: some View {
        HStack {
            Button {
                canvasManager.enableCrosshairs.toggle()
            } label: {
                Image(systemName: AppIcons.crosshairs)
                    .foregroundStyle(canvasManager.enableCrosshairs ? .blue : .secondary)
            }
            Divider()
                .frame(height: 10)
            
            Button {
                canvasManager.enableSnapping.toggle()
            } label: {
                Image(systemName: AppIcons.snapping)
                
                    .foregroundStyle(canvasManager.enableSnapping ? .blue : .secondary)
            }
            
            Divider()
                .frame(height: 10)
            Button {
                canvasManager.enableAxesBackground.toggle()
            } label: {
                Image(systemName: AppIcons.axesBackground)
                    .foregroundStyle(canvasManager.enableAxesBackground ? .blue : .secondary)
            }

           
            Divider()
                .frame(height: 10)
            
            Menu {
                
                Button {
                    canvasManager.backgroundStyle = .dotted
                } label: {
                    Label("Dotted Background", systemImage: canvasManager.backgroundStyle == .dotted ? AppIcons.checkmarkCircleFill : AppIcons.dottedBackground)
                        .labelStyle(.titleAndIcon)
                }
                Button {
                    canvasManager.backgroundStyle = .grid
                } label: {
                    Label("Grid Background", systemImage: canvasManager.backgroundStyle == .grid ? AppIcons.checkmarkCircleFill : AppIcons.gridBackground)
                        .labelStyle(.titleAndIcon)
                }
            } label: {
                Image(systemName: AppIcons.backgroundType)
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
