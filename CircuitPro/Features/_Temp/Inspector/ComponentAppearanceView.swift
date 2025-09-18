// Features/_Temp/Inspector/ComponentAppearanceView.swift
//
//  ComponentAppearanceView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 09.18.25.
//  Unified appearance view for SymbolNode and FootprintNode.
//

import SwiftUI
import SwiftDataPacks

struct ComponentAppearanceView: View {
    @Environment(\.projectManager) private var projectManager
    
    @Bindable var component: ComponentInstance
    @Bindable var node: BaseNode // Can be SymbolNode or FootprintNode

    private var currentEditor: EditorType {
        if node is SymbolNode {
            return .schematic
        } else if node is FootprintNode {
            return .layout
        }
        return .schematic // Default fallback
    }

    var body: some View {
        VStack(spacing: 5) {
            InspectorSection("Text Visibility") {
                PlainList {
                    textVisibilityListRow(label: "Name", content: .componentName)
                    textVisibilityListRow(label: "Reference", content: .componentReferenceDesignator)
                    
                    if let symbolNode = node as? SymbolNode, !component.displayedProperties.isEmpty {
                        Divider()
                        ForEach(component.displayedProperties) { property in
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
    private func textVisibilityListRow(label: String, content: CircuitTextContent) -> some View {
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
        guard let symbolNode = node as? SymbolNode,
              let symbolInstance = component.symbolInstance else { return EmptyView() }

        if let resolvedText = symbolInstance.resolvedItems.first(where: { $0.content.isSameType(as: content) }) {
            if case .componentProperty(let definitionID, let currentOptions) = resolvedText.content {
                let optionsBinding = Binding<TextDisplayOptions>(
                    get: { currentOptions },
                    set: { newOptions in
                        var editedText = resolvedText
                        editedText.content = .componentProperty(definitionID: definitionID, options: newOptions)
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
                    Toggle("Key", isOn: optionsBinding.showKey)
                    Toggle("Value", isOn: optionsBinding.showValue)
                    Toggle("Unit", isOn: optionsBinding.showUnit)
                }
                .controlSize(.small)
                .toggleStyle(.button)
            }
        }
    }

    // MARK: - Helpers (Internal, using `currentEditor`)
    
    private func toggleVisibility(for content: CircuitTextContent) {
        if case .componentProperty(let definitionID, _) = content, let symbolNode = node as? SymbolNode,
           let property = component.displayedProperties.first(where: { $0.id == definitionID }) {
            projectManager.togglePropertyVisibility(for: component, property: property)
        } else {
            projectManager.toggleDynamicTextVisibility(for: component, content: content, inEditor: currentEditor)
        }
    }
    
    private func isDynamicTextVisible(_ content: CircuitTextContent) -> Bool {
        return projectManager.isDynamicTextVisible(for: component, content: content, inEditor: currentEditor)
    }
}