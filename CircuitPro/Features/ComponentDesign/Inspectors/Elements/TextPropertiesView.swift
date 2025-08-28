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
            }
        }
        .padding(10)
    }
    
    /// Provides the correct view for editing the text's content,
    /// depending on whether it has a semantic source.
    @ViewBuilder
    private var contentSection: some View {
        let source = editor.textSourceMap[textModel.id]

        InspectorSection("Content") {
            if let source = source {
                // If the text has a source, it's derived from component data.
                let description = description(for: source)
                InspectorRow("Source") {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                // This branch is now only for truly static text that might be
                // part of a symbol but isn't linked to data.
                InspectorRow("Text") {
                    TextField("Static Text", text: $textModel.text)
                        .inspectorField()
                }
            }
            
            // This logic is still correct. Display options are only relevant for component properties.
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
        // --- MODIFIED: The switch statement now handles the new enum cases. ---
        switch source {
        case .componentAttribute(let attributeSource):
            // Use the string key from the type-safe source to provide a display name.
            switch attributeSource {
            case .name:
                return "Component Name"
            case .referenceDesignatorPrefix:
                return "Reference Designator"
            default:
                // This makes the UI robust for any future attributes you add.
                return attributeSource.key.capitalized
            }
            
        case .componentProperty(let defID):
            // This logic is unchanged but now correctly separated.
            return componentDesignManager.componentProperties.first { $0.id == defID }?.key.label ?? "Property"
        }
    }
}
