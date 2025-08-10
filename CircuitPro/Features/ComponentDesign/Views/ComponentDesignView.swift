//
//  ComponentDesignView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI

struct ComponentDesignView: View {

    @Environment(\.dismissWindow)
    private var dismissWindow

    @Environment(\.modelContext)
    private var modelContext

    @State private var componentDesignManager = ComponentDesignManager()

    @State private var currentStage: ComponentDesignStage = .details
    @State private var symbolCanvasManager = CanvasManager()
    @State private var footprintCanvasManager = CanvasManager()

    @State private var showError = false
    @State private var showWarning = false
    @State private var messages = [String]()
    @State private var didCreateComponent = false
    @State private var showFeedbackSheet: Bool = false

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
                ComponentDesignStageContainerView(
                    currentStage: $currentStage,
                    symbolCanvasManager: symbolCanvasManager,
                    footprintCanvasManager: footprintCanvasManager
                )
                .navigationTitle("Component Designer")
                .environment(componentDesignManager)
                .toolbar {
                    ToolbarItem {
                        Button {
                            createComponent()
                        } label: {
                            Text("Create Component")
                        }
                        .buttonStyle(.plain)
                        .directionalPadding(vertical: 5, horizontal: 7.5)
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(.rect(cornerRadius: 5))
                    }
                }
                .onChange(of: componentDesignManager.componentProperties) {
                    componentDesignManager.refreshValidation()
                }
            }
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackFormView(additionalContext: "Feedback sent from the Component Designer View, '\(currentStage.label)' stage.")
                .frame(minWidth: 400, minHeight: 300)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFeedbackSheet.toggle()
                } label: {
                    Image(systemName: CircuitProSymbols.Workspace.feedbackBubble)
                        .imageScale(.large)
                }
                .help("Send Feedback")
            }
        }
        .onAppear {
            symbolCanvasManager.paperSize = .component
            footprintCanvasManager.paperSize = .component
        }
        .alert("Error", isPresented: $showError, actions: {
          Button("OK", role: .cancel) { }
        }, message: {
          Text(messages.joined(separator: "\n"))
        })
        .alert("Warning", isPresented: $showWarning, actions: {
          Button("Cancel", role: .cancel) { }
        }, message: {
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

        let symbolEditor = componentDesignManager.symbolEditor
        let canvasSize = symbolCanvasManager.paperSize.canvasSize(orientation: .landscape)
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        var textDefinitions: [TextDefinition] = []
        let textNodes = symbolEditor.canvasNodes.compactMap { $0 as? TextNode }

        for textNode in textNodes {
            let relativePosition = CGPoint(x: textNode.position.x - anchor.x, y: textNode.position.y - anchor.y)
            var definition: TextDefinition

            if let source = symbolEditor.textSourceMap[textNode.id] {
                // This is dynamically sourced text (e.g., a property).
                let displayOptions = symbolEditor.textDisplayOptionsMap[textNode.id, default: .allVisible]
                
                definition = TextDefinition(
                    source: source,
                    relativePosition: relativePosition,
                    cardinalRotation: textNode.textModel.cardinalRotation,
                    displayOptions: displayOptions
                )
            } else {
                // This is static text.
                definition = TextDefinition(
                    source: .static(textNode.textModel.text),
                    relativePosition: relativePosition,
                    cardinalRotation: textNode.textModel.cardinalRotation
                )
            }
            
            // Preserve styling from the node's model.
            definition.font = textNode.textModel.font
            definition.color = textNode.textModel.color
            definition.alignment = textNode.textModel.alignment
            
            textDefinitions.append(definition)
        }
        
        let rawPrimitives: [AnyPrimitive] = symbolEditor.canvasNodes.compactMap { ($0 as? PrimitiveNode)?.primitive }
        
        let primitives = rawPrimitives.map { prim -> AnyPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        let rawPins = symbolEditor.pins
        let pins = rawPins.map { pin -> Pin in
            var copy = pin
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        let newComponent = Component(
            name: componentDesignManager.componentName,
            referenceDesignatorPrefix: componentDesignManager.referenceDesignatorPrefix,
            symbol: nil,
            footprints: [],
            category: componentDesignManager.selectedCategory,
            package: componentDesignManager.selectedPackageType,
            propertyDefinitions: componentDesignManager.componentProperties
        )

        let newSymbol = Symbol(
            name: componentDesignManager.componentName,
            component: newComponent,
            primitives: primitives,
            pins: pins,
            textDefinitions: textDefinitions
        )

        newComponent.symbol = newSymbol
        modelContext.insert(newComponent)
        didCreateComponent = true
    }
    private func resetForNewComponent() {
        componentDesignManager.resetAll()
        currentStage = .details
        symbolCanvasManager = CanvasManager()
        footprintCanvasManager = CanvasManager()
        didCreateComponent = false
    }
}
