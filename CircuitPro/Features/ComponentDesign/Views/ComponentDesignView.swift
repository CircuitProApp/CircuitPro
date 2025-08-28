//
//  ComponentDesignView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 18.06.25.
//

import SwiftUI
import SwiftDataPacks

struct ComponentDesignView: View {

    @Environment(\.dismissWindow)
    private var dismissWindow

    @UserContext private var userContext

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
            symbolCanvasManager.viewport.size = PaperSize.component.canvasSize()
            footprintCanvasManager.viewport.size = PaperSize.component.canvasSize()
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
        
        // --- THE REFACTORED LOGIC BEGINS HERE ---
        
        let symbolEditor = componentDesignManager.symbolEditor
        let canvasSize = symbolCanvasManager.viewport.size
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        let textNodes = symbolEditor.canvasNodes.compactMap { $0 as? TextNode }
        
        // Convert each TextNode from the canvas into a new CircuitText.Definition
        let textDefinitions: [CircuitText.Definition] = textNodes.map { textNode in
            let relativePosition = CGPoint(x: textNode.position.x - anchor.x, y: textNode.position.y - anchor.y)
            
            // Determine the content source and display options based on editor maps
            let contentSource: TextSource
            let displayOptions: TextDisplayOptions
            
            if let sourceFromMap = symbolEditor.textSourceMap[textNode.id] {
                contentSource = sourceFromMap
                displayOptions = symbolEditor.textDisplayOptionsMap[textNode.id, default: .default]
            } else {
                contentSource = .static(textNode.textModel.text)
                displayOptions = .default
            }
            
            // Create the new, immutable Definition struct by calling its single memberwise initializer.
            return CircuitText.Definition(
                id: UUID(), // A new, persistent ID for the data model
                contentSource: contentSource,
                text: "", // Not used by definitions, but required by the init
                displayOptions: displayOptions,
                relativePosition: relativePosition,
                anchorPosition: relativePosition, // For a new definition, these start identical
                font: textNode.textModel.font,
                color: textNode.textModel.color,
                anchor: textNode.textModel.anchor,
                alignment: textNode.textModel.alignment,
                cardinalRotation: textNode.textModel.cardinalRotation,
                isVisible: true
            )
        }
        
        // --- The rest of the creation logic remains the same ---
        
        let rawPrimitives: [AnyCanvasPrimitive] = symbolEditor.canvasNodes.compactMap { ($0 as? PrimitiveNode)?.primitive }
        
        let primitives = rawPrimitives.map { prim -> AnyCanvasPrimitive in
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
        
        guard let category = componentDesignManager.selectedCategory else { return }

        let newComponent = ComponentDefinition(
            name: componentDesignManager.componentName,
            referenceDesignatorPrefix: componentDesignManager.referenceDesignatorPrefix,
            symbol: nil,
            footprints: [],
            category: category,
            propertyDefinitions: componentDesignManager.componentProperties
        )

        let newSymbol = SymbolDefinition(
            name: componentDesignManager.componentName,
            component: newComponent,
            primitives: primitives,
            pins: pins,
            textDefinitions: textDefinitions // Use the newly created definitions
        )

        newComponent.symbol = newSymbol
        userContext.insert(newComponent)
        didCreateComponent = true
    }
    
    // --- resetForNewComponent remains the same ---
    private func resetForNewComponent() {
        componentDesignManager.resetAll()
        currentStage = .details
        symbolCanvasManager = CanvasManager()
        footprintCanvasManager = CanvasManager()
        didCreateComponent = false
    }
}
