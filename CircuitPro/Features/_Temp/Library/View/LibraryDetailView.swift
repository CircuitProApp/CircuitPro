//
//  LibraryDetailView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/18/25.
//

import SwiftUI

struct LibraryDetailView: View {
    
    @Binding var selectedComponent: Component?
    var body: some View {
        VStack {
            // Check if we have a selected component.
            if let component = selectedComponent {
                // If one is selected, display its name.
                Text(component.name)
                    .font(.title)
                    .foregroundStyle(.primary)
                // You could add more details here later.
                Text("Category: \(component.category.label)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                // If nothing is selected, show the placeholder text.
                Text("Nothing Selected")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
