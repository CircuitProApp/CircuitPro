//
//  PinEditorView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/2/25.
//

import SwiftUI

struct PinEditorView: View {

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    @State private var tab: EditorTab = .elements

    var body: some View {
        StageSidebarView {
            EditorTabPicker(selection: $tab)
            if tab == .elements {
                Text("Pins")
                    .font(.headline)
            } else {
                Text("Geometry")
                    .font(.headline)
            }
        } content: {
            switch tab {
            case .elements:
                pinSection
            case .geometry:
                
                @Bindable var manager = componentDesignManager
                // Correctly instantiate PrimitiveEditorView
                PrimitiveEditorView(
                    primitives: componentDesignManager.symbolPrimitives,
                    selectedIDs: $manager.selectedSymbolElementIDs,
                    bindingProvider: componentDesignManager.bindingForPrimitive
                )
            }
        }
    }

    // MARK: - Pins
    private var pinSection: some View {
        let pins = componentDesignManager.pins
        let selectedIDs = componentDesignManager.selectedSymbolElementIDs
        let selectedPins = componentDesignManager.selectedPins.sorted { $0.number < $1.number }

        return Group {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(pins) { pin in
                        let isSelected = selectedIDs.contains(pin.id)
                        Text(pin.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .directionalPadding(vertical: 5, horizontal: 7.5)
                            .background(isSelected ? .gray.opacity(0.3) : .gray.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 5))
                            .onTapGesture { togglePinSelection(pin: pin) }
                    }
                }
            }
            .scrollClipDisabled()

            if !selectedPins.isEmpty {
                Form {
                    ForEach(selectedPins) { pin in
                        if let binding = componentDesignManager.bindingForPin(with: pin.id) {
                            Section("Pin \(binding.wrappedValue.number) Properties") {
                                PinPropertiesView(pin: binding)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .listStyle(.inset)
            } else {
                placeholder("No pins selected")
            }
        }
    }

    // MARK: - Helpers
    private func togglePinSelection(pin: Pin) {
        if let element = componentDesignManager.symbolElements.first(where: {
            if case .pin(let pinElement) = $0 {
                return pinElement.id == pin.id
            } else {
                return false
            }
        }) {
            let id = element.id
            if componentDesignManager.selectedSymbolElementIDs.contains(id) {
                componentDesignManager.selectedSymbolElementIDs.remove(id)
            } else {
                componentDesignManager.selectedSymbolElementIDs.insert(id)
            }
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
    }
}
