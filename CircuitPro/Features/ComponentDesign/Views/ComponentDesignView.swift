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
        
        let symbolEditor = componentDesignManager.symbolEditor
        let canvasSize = symbolCanvasManager.viewport.size
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        
        let textNodes = symbolEditor.canvasNodes.compactMap { $0 as? TextNode }
        
        let textDefinitions: [CircuitText.Definition] = textNodes.compactMap { textNode in
            // All text in the symbol editor MUST have a source. If not, it's an
            // inconsistent state and we should ignore it.
            guard let contentSource = symbolEditor.textSourceMap[textNode.id] else {
                assertionFailure("TextNode found on canvas without a content source.")
                return nil
            }
            
            let relativePosition = CGPoint(x: textNode.position.x - anchor.x, y: textNode.position.y - anchor.y)
            let displayOptions = symbolEditor.textDisplayOptionsMap[textNode.id, default: .default]
            
            // Create the new Definition struct using its updated initializer.
            return CircuitText.Definition(
                id: UUID(), // A new, persistent ID for the data model
                contentSource: contentSource,
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
            category: category,
            referenceDesignatorPrefix: componentDesignManager.referenceDesignatorPrefix,
            propertyDefinitions: componentDesignManager.componentProperties,
            symbol: nil
        )
        
        let newSymbol = SymbolDefinition(
            primitives: primitives,
            pins: pins,
            textDefinitions: textDefinitions,
            component: newComponent
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
