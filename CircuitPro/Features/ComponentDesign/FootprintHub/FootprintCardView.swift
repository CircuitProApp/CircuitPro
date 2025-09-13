//
//  FootprintCardView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct FootprintCardView: View {
    
    let name: String
    
    var isSelected: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .aspectRatio(1, contentMode: .fit)
                
                Image(systemName: "square.grid.3x3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                }
            }
            
            Text(name)
                .font(.headline)
                .padding(.horizontal, 4)
                .lineLimit(1)
        }
        .contentShape(.rect)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}
