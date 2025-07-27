//
//  PadEditorView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 7/24/25.
//

import SwiftUI

struct PadEditorView: View {
    @Environment(\.componentDesignManager) private var componentDesignManager
    
    // 1. Use the shared EditorTab enum.
    // The default is .elements, which in this context means Pads.
    @State private var tab: EditorTab = .elements

    var body: some View {
        StageSidebarView {
            // 2. Use the reusable EditorTabPicker.
            EditorTabPicker(selection: $tab)
            
            // 3. Display a context-specific title based on the selection.
            if tab == .elements {
                Text("Pads")
                    .font(.headline)
            } else {
                Text("Geometry")
                    .font(.headline)
            }

        } content: {
            // 4. Switch the content based on the EditorTab case.
            switch tab {
            case .elements:
                padSection
            case .geometry:
                @Bindable var manager = componentDesignManager
                PrimitiveEditorView(
                    primitives: componentDesignManager.footprintPrimitives,
                    selectedIDs: $manager.selectedFootprintElementIDs,
                    bindingProvider: componentDesignManager.bindingForFootprintPrimitive
                )
            }
        }
        .validationStatus(componentDesignManager.validationState(for: ComponentDesignStage.FootprintRequirement.padDrillSize))
    }

    // MARK: - Pads
    // This entire section remains unchanged.
    private var padSection: some View {
        let pads = componentDesignManager.pads
        let selectedIDs = componentDesignManager.selectedFootprintElementIDs
        let selectedPads = componentDesignManager.selectedPads.sorted { $0.number < $1.number }

        return Group {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(pads) { pad in
                        let isSelected = selectedIDs.contains(pad.id)
                        Text("Pad \(pad.number)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .directionalPadding(vertical: 5, horizontal: 7.5)
                            .background(isSelected ? .gray.opacity(0.3) : .gray.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 5))
                            .onTapGesture {
                                togglePadSelection(pad: pad)
                            }
                    }
                }
            }
            .scrollClipDisabled()

            if !selectedPads.isEmpty {
                Form {
                    ForEach(selectedPads) { pad in
                        if let binding = componentDesignManager.bindingForPad(with: pad.id) {
                            Section("Pad \(binding.wrappedValue.number) Properties") {
                                PadPropertiesView(pad: binding)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .listStyle(.inset)
            } else {
                placeholder("No pads selected")
            }
        }
    }

    // MARK: - Helpers
    private func togglePadSelection(pad: Pad) {
        let id = pad.id
        if componentDesignManager.selectedFootprintElementIDs.contains(id) {
            componentDesignManager.selectedFootprintElementIDs.remove(id)
        } else {
            componentDesignManager.selectedFootprintElementIDs.insert(id)
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
