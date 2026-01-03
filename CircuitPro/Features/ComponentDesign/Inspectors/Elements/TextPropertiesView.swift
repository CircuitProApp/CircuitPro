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

    @Environment(CanvasEditorManager.self)
    private var editor

    let textID: UUID
    @Binding var text: CircuitText.Definition

    private var componentData: (name: String, prefix: String, properties: [Property.Definition]) {
        (
            componentDesignManager.componentName, componentDesignManager.referenceDesignatorPrefix,
            componentDesignManager.componentProperties
        )
    }

    // MARK: - Custom Bindings

    private var positionBinding: Binding<CGPoint> {
        Binding(
            get: { text.relativePosition },
            set: { newValue in
                var updated = text
                updated.relativePosition = newValue
                text = updated
            }
        )
    }

    private var anchorBinding: Binding<TextAnchor> {
        Binding(
            get: { text.anchor },
            set: { newValue in
                var updated = text
                updated.anchor = newValue
                text = updated
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Text Properties")
                .font(.title3.weight(.semibold))

            contentSection

            Divider()

            InspectorSection("Transform") {
                PointControlView(
                    title: "Position", point: positionBinding,
                    displayOffset: PaperSize.component.centerOffset())
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
        let content = text.content

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
                    TextField(
                        "Static Text",
                        text: Binding(
                            get: {
                                if case .static(let value) = text.content {
                                    return value
                                }
                                return ""
                            },
                            set: { newText in
                                var updated = text
                                updated.content = .static(text: newText)
                                text = updated
                            }
                        )
                    ).inspectorField()
                }
            }

            // Check for component properties and bind to their display options.
            if case .componentProperty = content {
                // Use the manager's helper to get a binding that handles the complex enum update.
                if let optionsBinding = editor.bindingForDisplayOptions(
                    with: textID, componentData: componentData)
                {

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

        case .componentProperty(let defID, _):  // Correctly ignore the options
            return componentDesignManager.componentProperties.first { $0.id == defID }?.key.label
                ?? "Property"

        case .static:  // Correctly ignore the associated text
            return "Static Text"
        }
    }
}
