//
//  PinEditorView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/2/25.
//

import SwiftUI

struct PinEditorView: View {
    @Environment(\.componentDesignManager) private var manager
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
                primitiveSection
            }
        }
    }

    // MARK: - Pins
    private var pinSection: some View {
        let pins = manager.pins
        let selectedIDs = manager.selectedSymbolElementIDs
        let selectedPins = manager.selectedPins.sorted { $0.number < $1.number }

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
                        if let binding = manager.bindingForPin(with: pin.id) {
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

    // MARK: - Geometry primitives
    private var primitiveSection: some View {
        let allElements = manager.symbolElements
        let selectedIDs = manager.selectedSymbolElementIDs
        let selectedElements = allElements.filter { selectedIDs.contains($0.id) }

        return VStack {
            // 1. Horizontal selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(allElements) { element in
                        if case .primitive(let prim) = element {
                            let isSel = selectedIDs.contains(prim.id)
                            Text("Primitive")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .directionalPadding(vertical: 5, horizontal: 7.5)
                                .background(isSel ? .gray.opacity(0.3) : .gray.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 5))
                                .onTapGesture { togglePrimitiveSelection(prim) }
                        }
                    }
                }
            }
            .scrollClipDisabled()

            // 2. Properties form
            if !selectedElements.isEmpty {
                Form {
                    ForEach(selectedElements) { element in
                        if case .primitive(let prim) = element {
                            if let binding = manager.bindingForPrimitive(with: prim.id) {
                                Section(" Properties") {
                                    PrimitivePropertiesView(primitive: binding)
                                }
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
    private func togglePinSelection(pin: Pin) {
        if let element = manager.symbolElements.first(where: {
            if case .pin(let pinElement) = $0 {
                return pinElement.id == pin.id
            } else {
                return false
            }
        }) {
            let id = element.id
            if manager.selectedSymbolElementIDs.contains(id) {
                manager.selectedSymbolElementIDs.remove(id)
            } else {
                manager.selectedSymbolElementIDs.insert(id)
            }
        }
    }
    private func togglePrimitiveSelection(_ prim: AnyPrimitive) {
        let id = prim.id
        if manager.selectedSymbolElementIDs.contains(id) {
            manager.selectedSymbolElementIDs.remove(id)
        } else {
            manager.selectedSymbolElementIDs.insert(id)
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

import SwiftUI

struct PrimitivePropertiesView: View {
    // 1. Binding to the selected primitive
    @Binding var primitive: AnyPrimitive

    var body: some View {
        // 2. Show a read-only summary based on the concrete primitive
        switch primitive {
        case .rectangle(let rect):
            rectangleSummary(rect)
        case .circle(let circ):
            circleSummary(circ)
        default:
            Text("Unsupported primitive")
                .foregroundStyle(.secondary)
        }
    }

    // 3. Rectangle summary
    private func rectangleSummary(_ rect: RectanglePrimitive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rectangle")
                .font(.headline)
            Text("Origin: (\(rect.position.x.formatted()), \(rect.position.y.formatted()))")
            Text("Size: \(rect.size.width.formatted()) × \(rect.size.height.formatted())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }

    // 4. Circle summary
    private func circleSummary(_ circ: CirclePrimitive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Circle")
                .font(.headline)
            Text("Center: (\(circ.position.x.formatted()), \(circ.position.y.formatted()))")
            Text("Radius: \(circ.radius.formatted())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }
}
