//
//  NavigatorDisclosureGroupStyle.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.06.25.
//

import SwiftUI

struct NavigatorDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    configuration.isExpanded.toggle()
                }
                
                
                
            } label: {
                HStack {
                    configuration.label
                        .disableAnimations()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .animation(.default, value: configuration.isExpanded)
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7.5)
 
            
            
            configuration.content
                .frame(height: configuration.isExpanded ? 180 : 0, alignment: .top)
                .clipped()
            
            
        }
    }
}
