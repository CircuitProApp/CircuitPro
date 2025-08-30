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
                        textVisibilityListRow(label: property.key.label, source: .componentProperty(definitionID: property.id))
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
        symbolNode.resolvedTexts.contains { resolvedText in
            resolvedText.isVisible && resolvedText.contentSource == source
        }
    }
}
