//
//  LibrarySearchView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import SwiftUI

struct LibrarySearchView: View {
    
    @Binding var searchText: String
    
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.secondary)
            
            TextField("Search Components", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear { isFocused = true }
            Spacer(minLength: 0)
            if searchText.isNotEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: CircuitProSymbols.Generic.xmark)
                        .symbolVariant(.circle.fill)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
            }

        }
        .padding(13)
        .font(.title2)
        
    }
}
