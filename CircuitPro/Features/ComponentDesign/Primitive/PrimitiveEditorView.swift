//
//  PrimitiveEditorView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PrimitiveEditorView: View {
    // 1. Data sources
    // The primitives are now passed as a simple array, not a binding.
    var primitives: [AnyPrimitive]
    // The selection set remains a binding, as the view needs to modify it.
    @Binding var selectedIDs: Set<UUID>
    // A closure that can provide a binding to a single primitive using its ID.
    var bindingProvider: (UUID) -> Binding<AnyPrimitive>?

    var body: some View {
        VStack {
            // 1. Horizontal selector for all available primitives
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(primitives) { primitive in
                        let isSelected = selectedIDs.contains(primitive.id)
                        Text(primitive.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .directionalPadding(vertical: 5, horizontal: 7.5)
                            .background(isSelected ? .gray.opacity(0.3) : .gray.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 5))
                            .onTapGesture {
                                toggleSelection(for: primitive)
                            }
                    }
                }
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, 10)

            // 2. Properties form for selected primitives
            let selectedPrimitives = primitives.filter { selectedIDs.contains($0.id) }
            
            if !selectedPrimitives.isEmpty {
                Form {
                    ForEach(selectedPrimitives) { primitive in
                        // Use the bindingProvider to get a binding for the specific primitive.
                        if let binding = bindingProvider(primitive.id) {
                            Section("\(primitive.displayName) Properties") {
                                PrimitivePropertiesView(primitive: binding)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .listStyle(.inset)
            } else {
                placeholder("No geometry selected")
            }
        }
    }

    // MARK: - Helpers
    private func toggleSelection(for primitive: AnyPrimitive) {
        if selectedIDs.contains(primitive.id) {
            selectedIDs.remove(primitive.id)
        } else {
            selectedIDs.insert(primitive.id)
        }
    }
    
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AnyPrimitive Extension
// A helper extension to get a user-friendly name for each primitive type.
extension AnyPrimitive {
    var displayName: String {
        switch self {
        case .rectangle:
            "Rectangle"
        case .circle:
            "Circle"
        case .line:
            "Line"
        }
    }
}
