//
//  LibraryPanelView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct LibraryPanelView: View {
    
    @State private var searchText: String = ""
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.secondary)
                
                TextField("App Components", text: $searchText)
                    .textFieldStyle(.plain)
                
                    .frame(minWidth: 50, alignment: .leading)
                    .focused($isFocused)
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
                
                
            }
            .padding(13)
            .font(.title2)
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "square")
                Image(systemName: "triangle")
                Image(systemName: "circle")
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
            .padding(10)
            .font(.title3)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack {
                        ForEach(0..<100, id: \.self) { int in
                            Text(int.description)
                        }
                    }
                    .frame(width: 272)
                }
                Divider()
                
                Text("Nothing Selected")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 682, minHeight: 373) // Set a default size for the panel
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 10))
        .onAppear {
            isFocused = true
        }
    }
}
