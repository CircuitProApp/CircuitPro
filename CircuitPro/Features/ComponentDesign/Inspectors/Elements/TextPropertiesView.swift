//
//  TextPropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/1/25
//

import SwiftUI

struct TextPropertiesView: View {
    
    @Environment(ComponentDesignManager.self)
    private var componentDesignManager
    
    // NEW: The view now needs the editor to access the display text map.
    @Environment(CanvasEditorManager.self)
    private var editor
    
    // The view correctly observes the TextNode as its primary source of truth.
    @Bindable var textNode: TextNode

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) {
        (componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix, componentDesignManager.componentProperties)
    }

    // MARK: - Custom Bindings (These are correct and unchanged)

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { textNode.resolvedText.relativePosition },
            set: { textNode.resolvedText.relativePosition = $0 }
        )
    }
    
    private var anchorBinding: Binding<TextAnchor> {
        Binding(
            get: { textNode.resolvedText.anchor },
            set: { textNode.resolvedText.anchor = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Text Properties")
                .font(.title3.weight(.semibold))
            
            contentSection

            Divider()
            
            InspectorSection("Transform") {
                PointControlView(title: "Position", point: positionBinding, displayOffset: PaperSize.component.centerOffset())
//                RotationControlView(object: $textModel, tickStepDegrees: 45, snapsToTicks: true)
            }
            
            Divider()

            InspectorSection("Appearance") {
                InspectorAnchorRow(textAnchor: anchorBinding)
            }
        }
        .padding(10)
    }
    
    // MARK: - Content Section (REWRITTEN)
    
    @ViewBuilder
    private var contentSection: some View {
        // Get the content enum directly from the node's data model.
        let content = textNode.resolvedText.content

        InspectorSection("Content") {
            // The description row remains, but uses the updated helper.
            InspectorRow("Source") {
                Text(description(for: content))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // If the content is static, provide an editable text field.
            if case .static = content {
                InspectorRow("Text") {
                    // This binding now correctly reads from and writes to the editor's displayTextMap.
                    TextField("Static Text", text: Binding(
                        get: {
                            // Read the current display text from the editor's map.
                            editor.displayTextMap[textNode.id] ?? ""
                        },
                        set: { newText in
                            // On edit, update both the map and the node's display text for live refresh.
                            editor.displayTextMap[textNode.id] = newText
                            textNode.displayText = newText
                            
                            // To persist the change to the *model* for static text, we must update the enum.
                            textNode.resolvedText.content = .static(text: newText)
                        }
                    )).inspectorField()
                }
            }
            
            // Check for component properties and bind to their display options.
            if case .componentProperty = content {
                // Use the manager's helper to get a binding that handles the complex enum update.
                if let optionsBinding = editor.bindingForDisplayOptions(with: textNode.id) {
                    
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
    
    // MARK: - Description Helper (UPDATED)
    
    /// Generates a human-readable description for a given `CircuitTextContent`.
    private func description(for content: CircuitTextContent) -> String {
        switch content {
        case .componentName:
            return "Component Name"
            
        case .componentReferenceDesignator:
            return "Reference Designator"
            
        case .componentProperty(let defID, _): // Correctly ignore the options
            return componentDesignManager.componentProperties.first { $0.id == defID }?.key.label ?? "Property"
            
        case .static: // Correctly ignore the associated text
            return "Static Text"
        }
    }
}
