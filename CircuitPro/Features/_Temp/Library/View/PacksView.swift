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
    var body: some View {
        
        if packManager.installedPacks.isEmpty {
            Text("No packs installed.")
        } else {
            List {
                ForEach(packManager.installedPacks) { pack in
                    Text(pack.metadata.title)
                }
            }
            .scrollContentBackground(.hidden)
        }
        
    }
}
