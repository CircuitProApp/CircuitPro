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
    
    @Bindable var component: ComponentInstance

    let symbolNode: SymbolNode
    
    var body: some View {
        VStack(spacing: 5) {
            InspectorSection("Text Visibility") {
                PlainList {
                    // This logic remains valid as it passes the correct content type.
                    textVisibilityListRow(label: "Name", content: .componentName)
                    textVisibilityListRow(label: "Reference", content: .componentReferenceDesignator)
                    
                    if !component.displayedProperties.isEmpty { Divider() }
                    
                    ForEach(component.displayedProperties) { property in
                        // Create a temporary content enum to use for searching.
                        // The actual options will be read from the resolved model.
                        let content: CircuitTextContent = .componentProperty(definitionID: property.id, options: .default)
                        let isVisible = isDynamicTextVisible(content)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            textVisibilityListRow(label: property.key.label, content: content)
                            if isVisible {
                                displayOptionsRow(for: content)
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
    
    // MARK: - Row Builders (Updated)
    
    @ViewBuilder
    private func textVisibilityListRow(label: String, content: CircuitTextContent) -> some View {
        // The logic here is unchanged, but it now relies on the corrected helper below.
        let isVisible = isDynamicTextVisible(content)
        
        HStack {
            Text(label).font(.callout)
            Spacer()
            Button {
                toggleVisibility(for: content)
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
    private func displayOptionsRow(for content: CircuitTextContent) -> some View {
        // 1. Find the text by its content type.
        if let resolvedText = component.symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
            
            // 2. Safely extract the definition ID and current options from the enum.
            if case .componentProperty(let definitionID, let currentOptions) = resolvedText.content {
                
                // 3. Create a single, robust binding for the whole TextDisplayOptions struct.
                let optionsBinding = Binding<TextDisplayOptions>(
                    get: {
                        // Use the options from the found model.
                        currentOptions
                    },
                    set: { newOptions in
                        // Reconstruct the enum with the new options and assign it back to the model.
                        var editedText = resolvedText
                        editedText.content = .componentProperty(definitionID: definitionID, options: newOptions)
                        // Have the manager apply the change.
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
                    // The toggles now correctly work with the derived binding.
                    Toggle("Key", isOn: optionsBinding.showKey)
                    Toggle("Value", isOn: optionsBinding.showValue)
                    Toggle("Unit", isOn: optionsBinding.showUnit)
                }
                .controlSize(.small)
                .toggleStyle(.button)
            }
        }
    }

    // MARK: - Helpers (Updated)
    
    private func toggleVisibility(for content: CircuitTextContent) {
        // This logic correctly delegates to the ProjectManager, which was previously updated.
        if case .componentProperty(let definitionID, _) = content,
           let property = component.displayedProperties.first(where: { $0.id == definitionID }) {
            projectManager.togglePropertyVisibility(for: component, property: property)
        } else {
            projectManager.toggleDynamicTextVisibility(for: component, content: content)
        }
    }
    
    private func isDynamicTextVisible(_ content: CircuitTextContent) -> Bool {
        // Find the resolved text by comparing its content type, then check its visibility.
        if let text = component.symbolInstance.resolvedItems.first(where: {
            $0.content.isSameType(as: content)
        }) {
            return text.isVisible
        }
        
        // If no text with that content type exists, it's not visible.
        return false
    }
}
