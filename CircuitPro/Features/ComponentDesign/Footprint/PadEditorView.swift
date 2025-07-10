import SwiftUI

struct PadEditorView: View {
    @Environment(\.componentDesignManager)
    private var componentDesignManager
    var body: some View {
        let pads = componentDesignManager.pads
        let selectedIDs = componentDesignManager.selectedFootprintElementIDs
        let selectedPads = componentDesignManager.selectedPads.sorted { $0.number < $1.number }

        StageSidebarView {
            Text("Pads")
                .font(.headline)
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
        } content: {
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
                Spacer()
                Text("No pads selected")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .validationStatus(componentDesignManager.validationState(for: ComponentDesignStage.FootprintRequirement.padDrillSize))
    }

    private func togglePadSelection(pad: Pad) {
        if let element = componentDesignManager.footprintElements.first(where: {
            if case .pad(let padElement) = $0 {
                return padElement.id == pad.id
            } else {
                return false
            }
        }) {
            let id = element.id
            if componentDesignManager.selectedFootprintElementIDs.contains(id) {
                componentDesignManager.selectedFootprintElementIDs.remove(id)
            } else {
                componentDesignManager.selectedFootprintElementIDs.insert(id)
            }
        }
    }
}
