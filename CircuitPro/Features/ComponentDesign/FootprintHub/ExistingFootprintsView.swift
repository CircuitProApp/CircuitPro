//
//  ExistingFootprintsView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 9/14/25.
//

import SwiftUI
import SwiftData

struct ExistingFootprintsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(ComponentDesignManager.self) private var componentDesignManager
    
    @Query var allFootprints: [FootprintDefinition]
    
    @State private var searchText: String = ""
    @State private var selection: Set<UUID> = []
    
    private var searchResults: [FootprintDefinition] {
        let assignedUUIDs = Set(componentDesignManager.assignedFootprints.map { $0.uuid })
        let availableFootprints = allFootprints.filter { !assignedUUIDs.contains($0.uuid) }
        
        if searchText.isEmpty {
            return availableFootprints
        } else {
            return availableFootprints.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Assign Existing Footprints")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all footprints...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.ultraThickMaterial)
            .clipShape(.rect(cornerRadius: 8))
            .padding(.horizontal)
            
            Divider().padding(.top)

            if searchResults.isNotEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)], spacing: 16) {
                        ForEach(searchResults) { footprint in
                            // CLEANER: The parent view now just passes the selection state to the card.
                            FootprintCardView(
                                name: footprint.name,
                                isSelected: selection.contains(footprint.uuid)
                            )
                            .onTapGesture {
                                if selection.contains(footprint.uuid) {
                                    selection.remove(footprint.uuid)
                                } else {
                                    selection.insert(footprint.uuid)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Text("No footprints found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered)
                Button(action: assignSelection) {
                    Text("Assign \(selection.count) Selected")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 650, minHeight: 400, idealHeight: 550)
    }
    
    private func assignSelection() {
        let selectedFootprints = allFootprints.filter { selection.contains($0.uuid) }
        componentDesignManager.assignedFootprints.append(contentsOf: selectedFootprints)
        dismiss()
    }
}
