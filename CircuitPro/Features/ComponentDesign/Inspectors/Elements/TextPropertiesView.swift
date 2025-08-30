//
//  TextPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/1/25
//

import SwiftUI

struct TextPropertiesView: View {
    
    // This part of your app seems to be using a ComponentDesignManager,
    // which is likely correct for a component editor context. No changes needed here.
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    @Binding var textModel: TextModel

    let editor: CanvasEditorManager

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    var body: some View {
        // --- NO CHANGES NEEDED IN THE BODY ---
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
            }
        }
        .padding(10)
    }
    
    /// Provides the correct view for editing the text's content.
    @ViewBuilder
    private var contentSection: some View {
        // --- NO CHANGES NEEDED HERE ---
        // This logic correctly adapts to whatever `TextSource` is provided.
        let source = editor.textSourceMap[textModel.id]

        InspectorSection("Content") {
            if let source = source {
                let description = description(for: source)
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
            
            if let source, case .componentProperty = source {
                if let optionsBinding = editor.bindingForDisplayOptions(with: textModel.id, componentData: componentData) {
                    
                    Text("Display Options").font(.caption).foregroundColor(.secondary)
                    
                    InspectorRow("Show Key") {
                        Toggle("Show Key", isOn: optionsBinding.showKey).labelsHidden()
                    }
                    InspectorRow("Show Value") {
                        Toggle("Show Value", isOn: optionsBinding.showValue).labelsHidden()
                    }
                    InspectorRow("Show Unit") {
                        Toggle("Show Unit", isOn: optionsBinding.showUnit).labelsHidden()
                    }
                }
            }
        }
    }
    
    /// Generates a human-readable description for a given semantic `TextSource`.
    private func description(for source: TextSource) -> String {
        switch source {
        case .componentName:
            return "Component Name"
            
        case .componentReferenceDesignator:
            return "Reference Designator"
            
        case .componentProperty(let defID):
            return componentDesignManager.componentProperties.first { $0.id == defID }?.key.label ?? "Property"
        }
    }
}
