import SwiftUI

struct ComponentDesignView: View {

    @Environment(\.dismissWindow)
    private var dismissWindow

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.componentDesignManager)
    private var componentDesignManager

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
            symbolCanvasManager.showGuides = true
            footprintCanvasManager.showGuides = true
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

    // 4. Build and insert component
    private func createComponent() {
        // --- Validation (Unchanged) ---
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

        // --- Symbol Creation (Updated Logic) ---
        let canvasSize = symbolCanvasManager.paperSize.canvasSize(orientation: .landscape)
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        // 1. Process all text elements to create anchored text definitions.
        var textDefinitions = [AnchoredTextDefinition]()
        let textCanvasElements = componentDesignManager.symbolElements.compactMap { element -> TextElement? in
            guard case .text(let textElement) = element else { return nil }
            return textElement
        }

        for textElement in textCanvasElements {
            let relativePosition = CGPoint(x: textElement.position.x - anchor.x, y: textElement.position.y - anchor.y)
            
            if let source = componentDesignManager.textSourceMap[textElement.id] {
                // THIS IS THE MODIFIED PART:
                // Get the display options for this element from the manager.
                let displayOptions = componentDesignManager.textDisplayOptionsMap[textElement.id, default: .allVisible]
                
                textDefinitions.append(AnchoredTextDefinition(
                    source: source,
                    relativePosition: relativePosition,
                    displayOptions: displayOptions // Pass the options during creation.
                ))
            } else {
                // Static text doesn't have display options.
                textDefinitions.append(AnchoredTextDefinition(
                    source: .static(textElement.text),
                    relativePosition: relativePosition
                ))
            }
        }
        
        // 2. Process primitives (excluding text elements).
        let rawPrimitives: [AnyPrimitive] = componentDesignManager.symbolElements.compactMap { element in
            if case .primitive(let primitive) = element { return primitive }
            return nil
        }

        let primitives = rawPrimitives.map { prim -> AnyPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        // 3. Process pins (their logic is separate and correct).
        let rawPins = componentDesignManager.pins
        let pins = rawPins.map { pin -> Pin in
            var copy = pin
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        // --- Database Insertion (Unchanged) ---
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
            // Use the new, correctly generated text definitions.
            anchoredTextDefinitions: textDefinitions
        )

        newComponent.symbol = newSymbol
        modelContext.insert(newComponent)
        didCreateComponent = true  // Flip the flag to show the success view.
    }

    // 5. Reset state if user wants to create another (Unchanged)
    private func resetForNewComponent() {
        // This correctly calls the updated `resetAll` method in the manager.
        componentDesignManager.resetAll()
        currentStage = .details
        symbolCanvasManager = CanvasManager()
        footprintCanvasManager = CanvasManager()
        didCreateComponent = false
    }
}
