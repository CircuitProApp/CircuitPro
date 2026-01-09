//
//  ComponentDesignView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftDataPacks
import SwiftUI

struct ComponentDesignView: View {

    @Environment(\.dismissWindow)
    private var dismissWindow

    @Environment(\.colorScheme)
    private var colorScheme

    @UserContext private var userContext

    @AppStorage(AppThemeKeys.canvasStyleList) private var stylesData = CanvasStyleStore
        .defaultStylesData
    @AppStorage(AppThemeKeys.canvasStyleSelectedLight) private var selectedLightStyleID =
        CanvasStyleStore.defaultSelectedLightID
    @AppStorage(AppThemeKeys.canvasStyleSelectedDark) private var selectedDarkStyleID =
        CanvasStyleStore.defaultSelectedDarkID

    @State private var componentDesignManager = ComponentDesignManager()

    @State private var symbolCanvasManager = CanvasManager()
    @State private var footprintCanvasManager = CanvasManager()

    @State private var showError = false
    @State private var showWarning = false
    @State private var messages = [String]()
    @State private var didCreateComponent = false

    var body: some View {
        Group {
            if didCreateComponent {
                ComponentDesignSuccessView(
                    onClose: {
                        dismissWindow.callAsFunction()
                        resetForNewComponent()
                    },
                    onCreateAnother: {
                        resetForNewComponent()
                    }
                )
                .navigationTitle("Component Designer")
            } else {
                NavigationSplitView {
                    ComponentDesignNavigator()
                } content: {
                    ComponentDesignContent(
                        symbolCanvasManager: symbolCanvasManager,
                        footprintCanvasManager: footprintCanvasManager)
                } detail: {
                    ComponentDesignInspector()
                }
                .environment(componentDesignManager)
                .toolbar {
                    ToolbarItem {
                        Button {
                            createComponent()
                        } label: {
                            Text("Create Component")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .onChange(of: componentDesignManager.componentProperties) {
                    componentDesignManager.refreshValidation()
                }
            }
        }
        .onAppear {
            symbolCanvasManager.viewport.size = PaperSize.component.canvasSize()
            footprintCanvasManager.viewport.size = PaperSize.component.canvasSize()
            applyThemes()
        }
        .onChange(of: stylesData) { applyThemes() }
        .onChange(of: selectedLightStyleID) { applyThemes() }
        .onChange(of: selectedDarkStyleID) { applyThemes() }
        .onChange(of: colorScheme) { applyThemes() }
        .alert(
            "Error", isPresented: $showError,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(messages.joined(separator: "\n"))
            }
        )
        .alert(
            "Warning", isPresented: $showWarning,
            actions: {
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text(messages.joined(separator: "\n"))
            })
    }

    private func createComponent() {
        if !componentDesignManager.validateForCreation() {
            let errorMessages = componentDesignManager.validationSummary.errors.values
                .flatMap { $0 }
                .map { $0.message }

            if !errorMessages.isEmpty {
                messages = errorMessages
                showError = true
            }
            return
        }

        let warningMessages = componentDesignManager.validationSummary.warnings.values
            .flatMap { $0 }
            .map { $0.message }

        if !warningMessages.isEmpty {
            messages = warningMessages
            showWarning = true
            return
        }

        guard let category = componentDesignManager.selectedCategory else { return }

        // 1. Create the base component definition
        let newComponent = ComponentDefinition(
            name: componentDesignManager.componentName,
            category: category,
            referenceDesignatorPrefix: componentDesignManager.referenceDesignatorPrefix,
            propertyDefinitions: componentDesignManager.componentProperties,
            symbol: nil
        )

        // 2. Create the symbol definition
        let symbolEditor = componentDesignManager.symbolEditor
        // NOTE: Using footprintCanvasManager.viewport.size since it's the same size.
        // Could also create a shared constant for this.
        let anchor = CGPoint(
            x: footprintCanvasManager.viewport.size.width / 2,
            y: footprintCanvasManager.viewport.size.height / 2)

        let symbolTextDefinitions = createTextDefinitions(from: symbolEditor, anchor: anchor)
        let symbolPrimitives = createPrimitives(from: symbolEditor, anchor: anchor)
        let symbolPins = symbolEditor.pins.map { pin -> Pin in
            var copy = pin
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        let newSymbol = SymbolDefinition(
            primitives: symbolPrimitives,
            pins: symbolPins,
            textDefinitions: symbolTextDefinitions,
            component: newComponent
        )
        newComponent.symbol = newSymbol

        // 3. Finalize the new footprint drafts
        var finalNewFootprints: [FootprintDefinition] = []
        for draft in componentDesignManager.footprintDrafts {
            let editor = draft.editor

            // Extract all necessary data from the editor.
            let primitives = createPrimitives(from: editor, anchor: anchor)
            let pads = editor.pads.map { pad -> Pad in
                var copy = pad
                copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
                return copy
            }
            let textDefinitions = createTextDefinitions(from: editor, anchor: anchor)

            let newFootprint = FootprintDefinition(
                name: draft.name,
                primitives: primitives,
                pads: pads,
                textDefinitions: textDefinitions
            )
            newFootprint.components.append(newComponent)
            finalNewFootprints.append(newFootprint)
        }

        // 4. Combine the newly created models with any pre-assigned ones.
        let allFootprints = finalNewFootprints + componentDesignManager.assignedFootprints
        newComponent.footprints = allFootprints

        // Also associate the component with any pre-existing, assigned footprints
        for assignedFootprint in componentDesignManager.assignedFootprints {
            assignedFootprint.components.append(newComponent)
        }

        // 5. Insert the new component into the data context.
        userContext.insert(newComponent)

        didCreateComponent = true
    }

    private func createPrimitives(from editor: CanvasEditorManager, anchor: CGPoint)
        -> [AnyCanvasPrimitive]
    {
        let rawPrimitives: [AnyCanvasPrimitive] = editor.primitives
        return rawPrimitives.map { prim -> AnyCanvasPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }
    }

    private func createTextDefinitions(from editor: CanvasEditorManager, anchor: CGPoint)
        -> [CircuitText.Definition]
    {
        let textItems = editor.items.compactMap { $0 as? CircuitText.Definition }

        return textItems.map { definition in
            let centeredPosition = CGPoint(
                x: definition.relativePosition.x - anchor.x,
                y: definition.relativePosition.y - anchor.y
            )
            let centeredAnchorPosition = CGPoint(
                x: definition.anchorPosition.x - anchor.x,
                y: definition.anchorPosition.y - anchor.y
            )

            return CircuitText.Definition(
                id: definition.id,
                content: definition.content,
                relativePosition: centeredPosition,
                anchorPosition: centeredAnchorPosition,
                font: definition.font,
                color: definition.color,
                anchor: definition.anchor,
                alignment: definition.alignment,
                cardinalRotation: definition.cardinalRotation,
                isVisible: definition.isVisible
            )
        }
    }

    private func applyThemes() {
        let styles = CanvasStyleStore.loadStyles(from: stylesData)
        let selectedID = colorScheme == .dark ? selectedDarkStyleID : selectedLightStyleID
        let style = CanvasStyleStore.selectedStyle(from: styles, selectedID: selectedID)
        let canvasTheme = CanvasThemeSettings.makeTheme(from: style)
        let schematicTheme = SchematicThemeSettings.makeTheme(from: style)
        symbolCanvasManager.applyTheme(canvasTheme)
        symbolCanvasManager.applySchematicTheme(schematicTheme)
        footprintCanvasManager.applyTheme(canvasTheme)
    }

    private func resetForNewComponent() {
        componentDesignManager.resetAll()
        componentDesignManager.currentStage = .details
        didCreateComponent = false
    }
}
