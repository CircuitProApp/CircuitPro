//
//  PackListRowView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PackListRowView: View {
    
    var pack: InstalledPack
    @Binding var selectedPack: InstalledPack?
    
    var isSelected: Bool {
        selectedPack == pack
    }
    
    var body: some View {
        HStack {
            Image(systemName: "shippingbox")
                .symbolVariant(.fill)
                .foregroundStyle(isSelected ? .white : .brown)
                .frame(width: 32, height: 32)
                .font(.title)
            Text(pack.metadata.title)
            Spacer()
            Text("v" + pack.metadata.version.description)
                .foregroundStyle(.secondary)
        }
        .padding(4)
        .background(isSelected ? Color.blue : Color.clear)
        .contentShape(.rect())
        .clipShape(.rect(cornerRadius: 8))
        .foregroundStyle(isSelected ? .white : .primary)
        .onTapGesture {
            selectedPack = pack
        }
    }
}
