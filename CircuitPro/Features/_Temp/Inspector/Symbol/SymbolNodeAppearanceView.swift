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
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    var body: some View {
        VStack(spacing: 15) {
            InspectorSection("Text Visibility") {
                PlainList {
                    textVisibilityListRow(
                        label: "Name",
                        source: .componentName
                    )
                    
                    textVisibilityListRow(
                        label: "Reference",
                        source: .reference
                    )
                    
                    if !component.displayedProperties.isEmpty {
                        Divider()
                    }
                    
                    ForEach(component.displayedProperties) { property in
                        textVisibilityListRow(
                            label: property.key.label,
                            source: .property(definitionID: property.id)
                        )
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
    
    // MARK: - Row Builder
    
    @ViewBuilder
    private func textVisibilityListRow(
        label: String,
        source: DynamicComponentProperty
    ) -> some View {
        let isVisible = isDynamicTextVisible(source)
        
        HStack {
            Text(label)
                .font(.callout)
            Spacer()
            Button {
                toggleVisibility(for: source)
            } label: {
                Image(systemName: CircuitProSymbols.Generic.eye)
                    .symbolVariant(isVisible ? .none : .slash)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(isVisible ? .blue : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers
    
    private func toggleVisibility(for source: DynamicComponentProperty) {
        switch source {
        case .reference, .componentName:
            projectManager.toggleDynamicTextVisibility(for: component, source: source, using: packManager)
        case .property(let definitionID):
            if let property = component.displayedProperties.first(where: {
                if case .definition(let id) = $0.source { return id == definitionID }
                return false
            }) {
                projectManager.togglePropertyVisibility(for: component, property: property, using: packManager)
            }
        }
    }
    
    private func isDynamicTextVisible(_ source: DynamicComponentProperty) -> Bool {
        symbolNode.resolvedTexts.contains { resolvedText in
            guard resolvedText.isVisible,
                  case .dynamic(let dynamicSource) = resolvedText.contentSource else {
                return false
            }
            return dynamicSource == source
        }
    }
}
