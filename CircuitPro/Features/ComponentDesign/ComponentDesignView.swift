import SwiftUI

struct ComponentDesignView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.componentDesignManager)
    private var componentDesignManager
    @State private var currentStage: ComponentDesignStage = .component
    @State private var symbolCanvasManager = CanvasManager()
    @State private var footprintCanvasManager = CanvasManager()
    var body: some View {
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
    }
    var stageIndicator: some View {
        HStack {
            ForEach(ComponentDesignStage.allCases) { stage in
                Text(stage.label)
                    .padding(10)
                    .background(currentStage == stage ? .blue : .clear)
                    .foregroundStyle(currentStage == stage ? .white : .secondary)
                    .clipShape(.capsule)
                    .onTapGesture {
                        currentStage = stage
                    }
                if stage == .component || stage == .symbol {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.headline)
        .padding()
    }

    private func createComponent() {

        // 0. Pick the anchor (see above)
        let anchor = CGPoint(x: 2_500, y: 2_500)

        // 1. Collect primitives & pins from the designer UI
        let rawPrimitives: [AnyPrimitive] =
            componentDesignManager.symbolElements.compactMap {
                if case .primitive(let p) = $0 { return p }
                return nil
            }
        let rawPins = componentDesignManager.pins

        // 2. Move them into symbol-local coordinates
        let primitives = rawPrimitives.map { $0.shifted(by: anchor) }
        let pins       = rawPins      .map { $0.shifted(by: anchor) }

        // 3. Build component & symbol
        let newComponent = Component(
            name       : componentDesignManager.componentName,
            abbreviation: componentDesignManager.componentAbbreviation,
            symbol     : nil,
            footprints : [],
            category   : componentDesignManager.selectedCategory,
            package    : componentDesignManager.selectedPackageType,
            properties : componentDesignManager.componentProperties
        )

        let newSymbol = Symbol(
            name      : componentDesignManager.componentName,
            component : newComponent,
            primitives: primitives,
            pins      : pins
        )

        newComponent.symbol = newSymbol
        modelContext.insert(newComponent)
        print("Inserted component: \(newComponent.name) with normalised symbol")
    }

}
