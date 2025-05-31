//
//  StatusBarView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct StatusBarView: View {
    
    var canvasManager: CanvasManager
    @Binding var showUtilityArea: Bool
    
    var body: some View {
        

        HStack {
            CanvasControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.leading, 4)
            Spacer()
            GridSpacingControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
//                .padding(.trailing, 4)
            ZoomControlView()
            Divider()
                .foregroundStyle(.quinary)
                .frame(height: 12)
                .padding(.trailing, 4)
            Button {
                withAnimation {
                    self.showUtilityArea.toggle()
                }
            } label: {
                Image(systemName: AppIcons.toggleUtilityArea)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
                    .fontWeight(.light)
                
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    StatusBarView(canvasManager: .init(), showUtilityArea: .constant(true))
}
