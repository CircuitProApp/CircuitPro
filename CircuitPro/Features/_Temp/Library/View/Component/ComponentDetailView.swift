//
//  ComponentDetailView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI

struct ComponentDetailView: View {
    
    @Environment(LibraryManager.self)
    private var libraryManager
    
    var body: some View {
        if let component = libraryManager.selectedComponent {
            VStack(alignment: .leading) {
                
                Text(component.name)
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Category: \(component.category.label)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
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
