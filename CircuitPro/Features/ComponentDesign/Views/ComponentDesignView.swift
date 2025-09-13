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
        let canvasSize = symbolCanvasManager.viewport.size
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

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
        for footprintDraft in componentDesignManager.newFootprints {
            // Find the temporary editor for this draft.
            guard let editor = componentDesignManager.footprintEditors[footprintDraft.uuid] else {
                print("Error: Could not find editor for footprint draft \(footprintDraft.name)")
                continue
            }

            // Extract the final primitives and pads from the editor.
            let primitives = createPrimitives(from: editor, anchor: anchor)
            let pads = editor.pads.map { pad -> Pad in
                var copy = pad
                copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
                return copy
            }

            // Update the draft model directly with the final data.
            footprintDraft.primitives = primitives
            footprintDraft.pads = pads
            footprintDraft.components.append(newComponent)
        }
        
        // 4. Combine new and assigned footprints
        let allFootprints = componentDesignManager.newFootprints + componentDesignManager.assignedFootprints
        newComponent.footprints = allFootprints
        
        // Also associate the component with any pre-existing, assigned footprints
        for assignedFootprint in componentDesignManager.assignedFootprints {
            assignedFootprint.components.append(newComponent)
        }

        // 5. Insert the new component into the data context.
        // SwiftData will automatically save the new footprints via the relationship.
        userContext.insert(newComponent)

        didCreateComponent = true
    }

    private func createPrimitives(from editor: CanvasEditorManager, anchor: CGPoint) -> [AnyCanvasPrimitive] {
        let rawPrimitives: [AnyCanvasPrimitive] = editor.canvasNodes.compactMap { ($0 as? PrimitiveNode)?.primitive }
        return rawPrimitives.map { prim -> AnyCanvasPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }
    }

    private func createTextDefinitions(from editor: CanvasEditorManager, anchor: CGPoint) -> [CircuitText.Definition] {
        let textNodes = editor.canvasNodes.compactMap { $0 as? TextNode }
        
        return textNodes.map { textNode in
            let model = textNode.resolvedText
            let centeredPosition = CGPoint(
                x: model.relativePosition.x - anchor.x,
                y: model.relativePosition.y - anchor.y
            )
            
            var finalContent = model.content
            if case .static = finalContent {
                let userEnteredText = editor.displayTextMap[textNode.id] ?? ""
                finalContent = .static(text: userEnteredText)
            }
            
            return CircuitText.Definition(
                id: model.id,
                content: finalContent,
                relativePosition: centeredPosition,
                anchorPosition: centeredPosition,
                font: model.font,
                color: model.color,
                anchor: model.anchor,
                alignment: model.alignment,
                cardinalRotation: model.cardinalRotation,
                isVisible: model.isVisible
            )
        }
    }
    
    private func resetForNewComponent() {
        componentDesignManager.resetAll()
        currentStage = .details
        symbolCanvasManager = CanvasManager()
        footprintCanvasManager = CanvasManager()
        didCreateComponent = false
    }
}
