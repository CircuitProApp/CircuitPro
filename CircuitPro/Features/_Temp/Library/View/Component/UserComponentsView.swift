//
//  UserComponentsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI
import SwiftDataPacks

struct UserComponentsView: View {
    
    @Query private var userComponents: [Component]
    
    @State private var selectedComponentID: UUID?
    
    var body: some View {
        List {
            ForEach(userComponents) { component in
                ComponentListRowView(component: component, selectedComponentID: $selectedComponentID)
            }
        }
    }
}
