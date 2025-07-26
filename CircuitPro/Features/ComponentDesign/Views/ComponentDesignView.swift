import SwiftUI

struct ComponentDesignView: View {

    @Environment(\.dismissWindow)
    private var dismissWindow

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.componentDesignManager)
    private var componentDesignManager

    @State private var currentStage: ComponentDesignStage = .component
    @State private var symbolCanvasManager = CanvasManager()
    @State private var footprintCanvasManager = CanvasManager()

    @State private var showError   = false
    @State private var showWarning = false
    @State private var messages    = [String]()
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
                VStack {
                    StageIndicatorView(
                        currentStage: $currentStage,
                        validationProvider: componentDesignManager.validationState
                    )
                    Spacer()
                    StageContentView(
                        left: {
                            switch currentStage {
                            case .footprint:
                                LayerTypeListView()
                                    .transition(.move(edge: .leading).combined(with: .blurReplace))
                                    .padding()
                            default:
                                Color.clear
                            }
                        },
                        center: {
                            switch currentStage {
                            case .component:
                                ComponentDetailView()
                            case .symbol:
                                SymbolDesignView()
                                    .environment(symbolCanvasManager)
                            case .footprint:
                                FootprintDesignView()
                                    .environment(footprintCanvasManager)
                            }
                        },
                        right: {
                            switch currentStage {
                            case .symbol:
                                if componentDesignManager.pins.isNotEmpty {
                                    PinEditorView()
                                        .transition(.move(edge: .trailing).combined(with: .blurReplace))
                                        .padding()
                                } else {
                                    Color.clear
                                }
                            case .footprint:
                                if componentDesignManager.pads.isNotEmpty {
                                    PadEditorView()
                                        .transition(.move(edge: .trailing).combined(with: .blurReplace))
                                        .padding()
                                } else {
                                    Color.clear
                                }
                            default:
                                Color.clear
                            }
                        }
                    )
                    Spacer()
                }
                .padding()
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
                        .clipAndStroke(with: RoundedRectangle(cornerRadius: 5))
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
        }
        .alert("Error", isPresented: $showError, actions: {
          Button("OK", role: .cancel) { }
        }, message: {
          Text(messages.joined(separator: "\n"))
        })
        .alert("Warning", isPresented: $showWarning, actions: {
//          Button("Continue") {
//            performCreation()  // proceed despite warnings
//          }
          Button("Cancel", role: .cancel) { }
        }, message: {
          Text(messages.joined(separator: "\n"))
        })
    }

    // 4. Build and insert component
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

        // Surface warnings (non-blocking)
        let warningMessages = componentDesignManager.validationSummary.warnings.values
            .flatMap { $0 }
            .map { $0.message }
            
        if !warningMessages.isEmpty {
            messages = warningMessages
            showWarning = true
            return
        }

        let canvasSize = symbolCanvasManager.paperSize.canvasSize(orientation: .landscape)
        let anchor = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        // 1. Process primitives (unchanged)
        let rawPrimitives: [AnyPrimitive] =
            componentDesignManager.symbolElements.compactMap {
                if case .primitive(let primitive) = $0 { return primitive }
                return nil
            }
        let primitives = rawPrimitives.map { prim -> AnyPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        // 2. Process pins (unchanged)
        let rawPins = componentDesignManager.pins
        let pins = rawPins.map { pin -> Pin in
            var copy = pin
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        // --- THIS IS THE NEW LOGIC FOR TESTING ---
        // 3. Create hardcoded default text definitions.
        // We will link them to the component's reference and name.
        let textDefinitions: [AnchoredTextDefinition] = [
            AnchoredTextDefinition(
                // This label will display the reference designator (e.g., "R1")
                defaultText: componentDesignManager.componentAbbreviation,
                // Position it 20 points above the symbol's origin
                relativePosition: CGPoint(x: 0, y: 20)
            )
        ]
        // --- END OF NEW LOGIC ---

        let newComponent = Component(
            name: componentDesignManager.componentName,
            abbreviation: componentDesignManager.componentAbbreviation,
            symbol: nil,
            footprints: [],
            category: componentDesignManager.selectedCategory,
            package: componentDesignManager.selectedPackageType,
            propertyDefinitions: componentDesignManager.componentProperties // Corrected from your provided snippet
        )

        let newSymbol = Symbol(
            name: componentDesignManager.componentName,
            component: newComponent,
            primitives: primitives,
            pins: pins,
            // --- PASS THE NEW DEFINITIONS TO THE SYMBOL ---
            anchoredTextDefinitions: textDefinitions
        )

        newComponent.symbol = newSymbol
        modelContext.insert(newComponent)
        didCreateComponent = true  // flip the flag
    }

    // 5. Reset state if user wants to create another
    private func resetForNewComponent() {
        componentDesignManager.resetAll()
        currentStage = .component
        symbolCanvasManager = CanvasManager()
        footprintCanvasManager = CanvasManager()
        didCreateComponent = false
    }

}
