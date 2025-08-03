//
//  TextPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/1/25.
//

import SwiftUI

struct TextPropertiesView: View {
    @Binding var textElement: TextElement
    let editor: CanvasEditorManager
    @Environment(\.componentDesignManager) private var componentDesignManager
    
    private var componentData: (name: String, prefix: String, properties: [PropertyDefinition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Text Properties")
                .font(.title3.weight(.semibold))
            
            // 1. Content Section
            contentSection

            Divider()
            
            // 2. Transform Section
            InspectorSection("Transform") {
                PointControlView(title: "Position", point: $textElement.position, displayOffset: PaperSize.component.centerOffset())
                RotationControlView(object: $textElement, tickStepDegrees: 45, snapsToTicks: true)
            }
            
            Divider()

            // 3. Appearance Section
            InspectorSection("Appearance") {
                // In a real app, you'd have font pickers etc.
                // For now, these are placeholders.
                InspectorRow("Font") {
                    TextField("Font Name", text: .constant(textElement.font.fontName))
                        .inspectorField()
                }
                InspectorRow("Size") {
                    InspectorNumericField(title: "Size", value: .constant(textElement.font.pointSize))
                }
            }
        }
        .padding(10)
    }
    
    /// Provides the correct view for editing the text's content,
    /// depending on whether it is static or dynamically linked to a property.
    @ViewBuilder
    private var contentSection: some View {
        let source = editor.textSourceMap[textElement.id]

        InspectorSection("Content") {
            // This part is the same: Show the source description.
            if let dynamicSource = source {
                let description = description(for: dynamicSource)
                InspectorRow("Source") {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                InspectorRow("Text") {
                    TextField("Static Text", text: $textElement.text)
                        .inspectorField()
                }
            }
            
            // If the source is a property, show the display option toggles.
            if let source, case .dynamic(.property) = source {
                // Get a binding to the display options from the manager.
                if let optionsBinding = editor.bindingForDisplayOptions(with: textElement.id, componentData: componentData) {
                    
                    Text("Display Options").font(.caption).foregroundColor(.secondary)
                    
                    InspectorRow("Show Key") {
                        Toggle("Show Key", isOn: optionsBinding.showKey)
                            .labelsHidden()
                    }
                    InspectorRow("Show Value") {
                        Toggle("Show Value", isOn: optionsBinding.showValue)
                            .labelsHidden()
                    }
                    InspectorRow("Show Unit") {
                        Toggle("Show Unit", isOn: optionsBinding.showUnit)
                            .labelsHidden()
                    }
                }
            }
        }
    }
    
    private func description(for source: TextSource) -> String {
        switch source {
        case .dynamic(.componentName):
            return "Component Name"
        case .dynamic(.reference):
            return "Reference Designator"
        case .dynamic(.property(let defID)):
            return componentDesignManager.componentProperties.first { $0.id == defID }?.key.label ?? "Property"
        case .static(let txt):
            return "Static: \(txt)"
        }
    }
}
