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
    var body: some View {
        let pins = componentDesignManager.pins
        let selectedIDs = componentDesignManager.selectedSymbolElementIDs
        let selectedPins = componentDesignManager.selectedPins.sorted { $0.number < $1.number }

        StageSidebarView {
            Text("Pins")
                .font(.headline)
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
                            .onTapGesture {
                                togglePinSelection(pin: pin)
                            }
                    }
                }
            }
            .scrollClipDisabled()
        } content: {
            if !selectedPins.isEmpty {
                Form {
                    ForEach(selectedPins) { pin in
                        if let binding = componentDesignManager.bindingForPin(with: pin.id) {
                            Section("Pin \(binding.wrappedValue.number.description) Properties") {
                                PinPropertiesView(pin: binding)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .listStyle(.inset)
            } else {
                Spacer()
                Text("No pins selected")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

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
}
