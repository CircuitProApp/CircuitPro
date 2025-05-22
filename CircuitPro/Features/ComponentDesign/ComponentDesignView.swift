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
                    case .footprint:
                        LayerTypeListView()
                            .transition(.move(edge: .leading).combined(with: .blurReplace))
                            .padding()
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
        let newComponent = Component(
            name: componentDesignManager.componentName,
            abbreviation: componentDesignManager.componentAbbreviation,
            symbol: nil,
            footprints: [],
            category: componentDesignManager.selectedCategory,
            package: componentDesignManager.selectedPackageType,
            properties: componentDesignManager.componentProperties
        )
        let graphicPrimitives: [AnyPrimitive] = componentDesignManager.symbolElements.compactMap {
            if case .primitive(let prim) = $0 { return prim }
            return nil
        }
        let newComponentSymbol = Symbol(
            name: componentDesignManager.componentName,
            component: newComponent,
            primitives: graphicPrimitives,
            pins: componentDesignManager.pins
        )
        newComponent.symbol = newComponentSymbol
        modelContext.insert(newComponent)
    }
}

private struct StageContentView<Left: View, Center: View, Right: View>: View {
    let left: Left
    let center: Center
    let right: Right
    let width: CGFloat
    let height: CGFloat
    let sidebarWidth: CGFloat
    init(
        width: CGFloat = 800,
        height: CGFloat = 500,
        sidebarWidth: CGFloat = 325,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
        self.width = width
        self.height = height
        self.sidebarWidth = sidebarWidth
    }
    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: sidebarWidth, height: height)
                .zIndex(0)
            center.frame(width: width, height: height)
                .zIndex(1)
            right.frame(width: sidebarWidth, height: height)
                .zIndex(0)
        }
    }
}

struct StageSidebarView<Header: View, Content: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .border(edge: .bottom, style: .gray.opacity(0.3))
            content
        }
        .frame(maxHeight: .infinity)
        .clipAndStroke(with: RoundedRectangle(cornerRadius: 15))
    }
}
