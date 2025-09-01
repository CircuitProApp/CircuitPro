//
//  SymbolNodeAppearanceView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeAppearanceView: View {
    @Environment(\.projectManager) private var projectManager
    @PackManager private var packManager
    
    let component: ComponentInstance
    @Bindable var symbolNode: SymbolNode
    
    var body: some View {
        VStack(spacing: 5) {
            InspectorSection("Text Visibility") {
                PlainList {
                    textVisibilityListRow(label: "Name", source: .componentName)
                    textVisibilityListRow(label: "Reference", source: .componentReferenceDesignator)
                    
                    if !component.displayedProperties.isEmpty { Divider() }
                    
                    ForEach(component.displayedProperties) { property in
                        let source: TextSource = .componentProperty(definitionID: property.id)
                        let isVisible = isDynamicTextVisible(source)
                        VStack(alignment: .leading, spacing: 6) {
                            textVisibilityListRow(label: property.key.label, source: source)
                            if isVisible {
                                displayOptionsRow(for: source)
                            }
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipAndStroke(with: .rect(cornerRadius: 5))
                .listConfiguration { configuration in
                    configuration.listRowPadding = .horizontal(7.5, vertical: 5)
                }
                .padding(.horizontal, 5)
            }
        }
    }
    
    // MARK: - Row Builders
    
    @ViewBuilder
    private func textVisibilityListRow(label: String, source: TextSource) -> some View {
        let isVisible = isDynamicTextVisible(source)
        
        HStack {
            Text(label).font(.callout)
            Spacer()
            Button {
                toggleVisibility(for: source)
            } label: {
                Image(systemName: "eye")
                    .symbolVariant(isVisible ? .none : .slash)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(isVisible ? .blue : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func displayOptionsRow(for source: TextSource) -> some View {
        // Use `if let` instead of `guard let` inside a @ViewBuilder.
        // If this fails, the builder automatically produces nothing (an EmptyView).
        if let resolvedText = component.symbolInstance.resolvedItems.first(where: { $0.contentSource == source }) {
            
            // This code only runs if the resolvedText was found.
            
            let keyBinding = Binding<Bool>(
                get: { resolvedText.displayOptions.showKey },
                set: { wantsToShowKey in
                    var editedText = resolvedText
                    editedText.displayOptions.showKey = wantsToShowKey
                    projectManager.updateText(for: component, with: editedText)
                }
            )
            
            let valueBinding = Binding<Bool>(
                get: { resolvedText.displayOptions.showValue },
                set: { wantsToShowValue in
                    var editedText = resolvedText
                    editedText.displayOptions.showValue = wantsToShowValue
                    projectManager.updateText(for: component, with: editedText)
                }
            )
            
            let unitBinding = Binding<Bool>(
                get: { resolvedText.displayOptions.showUnit },
                set: { wantsToShowUnit in
                    var editedText = resolvedText
                    editedText.displayOptions.showUnit = wantsToShowUnit
                    projectManager.updateText(for: component, with: editedText)
                }
            )
            
            HStack(spacing: 8) {
                Text("Display Options")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Toggle("Key", isOn: keyBinding)
                Toggle("Value", isOn: valueBinding)
                Toggle("Unit", isOn: unitBinding)
            }
            .controlSize(.small)
            .toggleStyle(.button)
            
        }
    }

    // MARK: - Helpers
    
    private func toggleVisibility(for source: TextSource) {
        if case .componentProperty(let definitionID) = source,
           let property = component.displayedProperties.first(where: { $0.id == definitionID }) {
            projectManager.togglePropertyVisibility(for: component, property: property)
        } else {
            projectManager.toggleDynamicTextVisibility(for: component, source: source)
        }
    }
    
    private func isDynamicTextVisible(_ source: TextSource) -> Bool {
        // The @ResolvableDestination macro on SymbolInstance generates `resolvedCircuitTexts`.
        // This is the single source of truth for the current state.
        // The `component` is an @Observable class, so SwiftUI will automatically
        // track changes to its `symbolInstance` and its properties.
        if let text = component.symbolInstance.resolvedItems.first(where: { $0.contentSource == source }) {
            return text.isVisible
        }
        
        // If a text doesn't exist in the resolved list, it's not visible.
        return false
    }
}
