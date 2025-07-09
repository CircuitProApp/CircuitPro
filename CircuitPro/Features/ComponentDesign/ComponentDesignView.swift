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
                // 2. Success screen
                VStack(spacing: 20) {
                    Image(systemName: CircuitProSymbols.Generic.checkmark)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.primary, .green.gradient)
                    Text("Component created successfully")
                        .font(.title)
                        .foregroundStyle(.primary)
                    HStack {
                        Button {
                            dismissWindow.callAsFunction()
                            resetForNewComponent()
                        } label: {
                            Text("Close Window")
                        }

                        Button("Create Another") {
                            resetForNewComponent()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .navigationTitle("Component Designer")
            } else {
                // 3. Original design UI
                VStack {
                    stageIndicator
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
                .onAppear {
                    symbolCanvasManager.showDrawingSheet = false
                    footprintCanvasManager.showDrawingSheet = false
                }
                .onChange(of: componentDesignManager.componentName)         { componentDesignManager.refreshValidation() }
                .onChange(of: componentDesignManager.componentAbbreviation) { componentDesignManager.refreshValidation() }
                .onChange(of: componentDesignManager.selectedCategory)      { componentDesignManager.refreshValidation() }
                .onChange(of: componentDesignManager.componentProperties) { componentDesignManager.refreshValidation() }
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
            let errorMessages = componentDesignManager.validationSummary.errors.values.map { $0 }
            if !errorMessages.isEmpty {
                messages = errorMessages
                showError = true
            }
            return
        }

        // Surface warnings (non-blocking)
        let warningMessages = componentDesignManager.validationSummary.warnings.values.map { $0 }
        if !warningMessages.isEmpty {
            messages = warningMessages
            showWarning = true
            return
        }

        let anchor = CGPoint(x: 2_500, y: 2_500)

        let rawPrimitives: [AnyPrimitive] = 
            componentDesignManager.symbolElements.compactMap {
                if case .primitive(let primitive) = $0 { return primitive }
                return nil
            }
        let rawPins = componentDesignManager.pins

        let primitives = rawPrimitives.map { prim -> AnyPrimitive in
            var copy = prim
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }
        let pins = rawPins.map { pin -> Pin in
            var copy = pin
            copy.translate(by: CGVector(dx: -anchor.x, dy: -anchor.y))
            return copy
        }

        let newComponent = Component(
            name: componentDesignManager.componentName,
            abbreviation: componentDesignManager.componentAbbreviation,
            symbol: nil,
            footprints: [],
            category: componentDesignManager.selectedCategory,
            package: componentDesignManager.selectedPackageType,
            properties: componentDesignManager.componentProperties
        )

        let newSymbol = Symbol(
            name: componentDesignManager.componentName,
            component: newComponent,
            primitives: primitives,
            pins: pins
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

    private var stageIndicator: some View {
        HStack {
            ForEach(ComponentDesignStage.allCases) { stage in
                StagePill(stage: stage,
                          isSelected: currentStage == stage,
                          hasErrors:   stage == .component &&
                                       !componentDesignManager.validationSummary.errors.isEmpty,
                          hasWarnings: stage == .component &&
                                       componentDesignManager.validationSummary.errors.isEmpty &&
                                       !componentDesignManager.validationSummary.warnings.isEmpty)
                    .onTapGesture { currentStage = stage }

            }
        }
        .font(.headline)
        .padding()
    }
}

struct StagePill: View {
    let stage: ComponentDesignStage
    let isSelected: Bool
    let hasErrors: Bool
    let hasWarnings: Bool          // ← NEW

    var body: some View {
        Text(stage.label)
            .padding(10)
            .background(isSelected ? .blue : .clear)
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(.capsule)
            .overlay(alignment: .topTrailing) {
                if hasErrors {
                    Image(systemName: "exclamationmark.circle.fill")   // red
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .offset(x: 6, y: -6)
                } else if hasWarnings {
                    Image(systemName: "exclamationmark.triangle.fill") // yellow
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .yellow)
                        .offset(x: 6, y: -6)
                }
            }
    }
}



