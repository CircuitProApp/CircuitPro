//
//  PacksView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct PacksView: View {
    
    @PackManager private var packManager
    
    @State private var selectedPack: InstalledPack?

    var body: some View {
        if packManager.installedPacks.isEmpty {
            Text("No packs installed.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(packManager.installedPacks) { pack in
                            PackListRowView(pack: pack, selectedPack: $selectedPack)
                                .padding(.horizontal, 6)
                        }
                    } header: {
                        Text("Installed Packs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(2.5)
                            .background(.ultraThinMaterial)
                    }
                    Section("???") {
                        //ForEach of downloadable packs is here
                    }
                }
                
            }
        }
    }
}
