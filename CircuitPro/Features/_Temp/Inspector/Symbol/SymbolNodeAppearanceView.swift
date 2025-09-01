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
//        let keyBinding = Binding<Bool>(
//            get: { projectManager.displayOptions(for: component, source: source).showKey },
//            set: { newValue in
//                var options = projectManager.displayOptions(for: component, source: source)
//                options.showKey = newValue
//                projectManager.setDisplayOptions(for: component, source: source, options: options)
//            }
//        )
//        let valueBinding = Binding<Bool>(
//            get: { projectManager.displayOptions(for: component, source: source).showValue },
//            set: { newValue in
//                var options = projectManager.displayOptions(for: component, source: source)
//                options.showValue = newValue
//                projectManager.setDisplayOptions(for: component, source: source, options: options)
//            }
//        )
//        let unitBinding = Binding<Bool>(
//            get: { projectManager.displayOptions(for: component, source: source).showUnit },
//            set: { newValue in
//                var options = projectManager.displayOptions(for: component, source: source)
//                options.showUnit = newValue
//                projectManager.setDisplayOptions(for: component, source: source, options: options)
//            }
//        )
        
        HStack(spacing: 8) {
            Text("Display Options")
                .foregroundStyle(.secondary)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
//            Toggle("Key", isOn: keyBinding)
//            Toggle("Value", isOn: valueBinding)
//            Toggle("Unit", isOn: unitBinding)
        }
        .controlSize(.small)
        .toggleStyle(.button)
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
        // Force the view to observe changes coming from ProjectManager so the row re-renders.
        // canvasNodes changes on every rebuild after toggling visibility.
        _ = projectManager.canvasNodes.count
        
        // Prefer definition-based visibility (with overrides) if the text is defined on the symbol.
        if let symbol = component.definition?.symbol,
           let def = symbol.textDefinitions.first(where: { $0.contentSource == source }) {
            if let override = component.symbolInstance.textOverrides.first(where: { $0.definitionID == def.id }),
               let isVisible = override.isVisible {
                return isVisible
            }
            // If no override exists, assume definition defaults to visible.
            return true
        }
        
        // Otherwise, check for an instance-based text and use its visibility.
        if let inst = component.symbolInstance.textInstances.first(where: { $0.contentSource == source }) {
            return inst.isVisible
        }
        
        // If there's no definition or instance, it's effectively not visible.
        return false
    }
}
