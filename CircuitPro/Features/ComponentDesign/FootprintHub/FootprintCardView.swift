//
//  FootprintCardView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 9/13/25.
//

import SwiftUI

struct FootprintCardView: View {
    
    // CHANGED: The card now only needs the name to display.
    // This makes it reusable for both FootprintDefinition and FootprintDraft.
    let name: String
    
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
            
            // Displays the name that was passed in.
            Text(name)
                .font(.headline)
                .padding(.horizontal, 4)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }
}
