//
//  PackDetailView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/20/25.
//

import SwiftUI

struct PackDetailView: View {
    
    @Environment(LibraryManager.self)
    private var libraryManager
    
    var body: some View {
        if libraryManager.selectedPack != nil {
            VStack(alignment: .leading) {
                HStack {
                    Text(libraryManager.selectedPack?.title ?? "Unknown Pack")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text(libraryManager.selectedPack?.version ?? "Unknown Version")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text("v" + (libraryManager.selectedPack?.description ?? "Unknown Description"))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        } else {
            Text("Nothing Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
