//
//  TextPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/1/25.
//

import SwiftUI

struct TextPropertiesView: View {
    
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    @Binding var textModel: TextModel

    let editor: CanvasEditorManager

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Text Properties")
                .font(.title3.weight(.semibold))
            
            contentSection

            Divider()
            
            InspectorSection("Transform") {
                PointControlView(title: "Position", point: $textModel.position, displayOffset: PaperSize.component.centerOffset())
                RotationControlView(object: $textModel, tickStepDegrees: 45, snapsToTicks: true)
            }
            
            Divider()

            InspectorSection("Appearance") {
                InspectorAnchorRow(textAnchor: $textModel.anchor)
//                InspectorRow("Font") {
//                    TextField("Font Name", text: .constant(textModel.font.fontName))
//                        .inspectorField()
//                }
//                InspectorRow("Size") {
//                    InspectorNumericField(label: "Size", value: .constant(textModel.font.pointSize))
//                }
            }
        }
        .padding(10)
    }
    
    /// Provides the correct view for editing the text's content,
    /// depending on whether it is static or dynamically linked to a property.
    @ViewBuilder
    private var contentSection: some View {
        let source = editor.textSourceMap[textModel.id]

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
                    TextField("Static Text", text: $textModel.text)
                        .inspectorField()
                }
            }
            
            // If the source is a property, show the display option toggles.
            if let source, case .dynamic(.property) = source {
                // Get a binding to the display options from the manager.
                if let optionsBinding = editor.bindingForDisplayOptions(with: textModel.id, componentData: componentData) {
                    
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
