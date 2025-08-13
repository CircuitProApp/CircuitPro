//
//  AnchorPickerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/13/25.
//

import SwiftUI

struct AnchorPickerView: View {
    // State to hold the currently selected anchor
    @Binding var selectedAnchor: TextAnchor
    
    // Layout the anchors in a 2D array for the grid
    private let anchors: [[TextAnchor]] = [
        [.topLeft, .topCenter, .topRight],
        [.middleLeading, .middleCenter, .middleTrailing],
        [.bottomLeft, .bottomCenter, .bottomRight]
    ]
    
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<3) { row in
                GridRow {
                    ForEach(0..<3) { col in
                        let anchor = anchors[row][col]
                        Button{
                            selectedAnchor = anchor
                        } label: {
                            ZStack {
                                Rectangle()
                                    .fill(selectedAnchor == anchor ? Color(nsColor: .controlAccentColor) : Color(nsColor: .controlBackgroundColor))
                                    .clipShape(.rect(cornerRadius: 2))
                               
                                
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 3.5))
                                    .foregroundColor(selectedAnchor == anchor ? .white : .primary)
                                
                                
                            }
                           
                            
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 27, height: 27)
        .clipAndStroke(with: .rect(cornerRadius: 3.5))
        .padding(5)
    }
}
