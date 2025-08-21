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
                HStack(spacing: 4) {
                    Text(libraryManager.selectedPack?.title ?? "Unknown Pack")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("v" + (libraryManager.selectedPack?.version ?? "Unknown Version"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text(libraryManager.selectedPack?.description ?? "Unknown Description")
                    .font(.callout)
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
