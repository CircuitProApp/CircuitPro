//
//  SplitView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 31.05.25.
//
import SwiftUI

struct SplitView<TopContent: View, DividerContent: View, BottomContent: View>: View {
    @Binding var showBottomView: Bool
    let topView: TopContent
    let dividerView: DividerContent
    let bottomView: BottomContent
    
    init(showBottomView: Binding<Bool>,
         @ViewBuilder topView: () -> TopContent,
         @ViewBuilder dividerView: () -> DividerContent,
         @ViewBuilder bottomView: () -> BottomContent) {
        self._showBottomView = showBottomView
        self.topView = topView()
        self.dividerView = dividerView()
        self.bottomView = bottomView()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topView
            Divider()
                .foregroundStyle(.quaternary)
            dividerView
                .frame(height: 30)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12.5)
            Divider()
                .foregroundStyle(.quaternary)
            if showBottomView {
                bottomView
                    .frame(height: 200)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

