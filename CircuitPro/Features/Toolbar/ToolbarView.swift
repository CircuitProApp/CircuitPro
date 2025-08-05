import SwiftUI

/// A generic toolbar driven by an array of `CanvasTool` instances.
struct ToolbarView: View {

    // MARK: - Properties
    
    let tools: [CanvasTool]
    @Binding var selectedTool: CanvasTool? // Use the base class and make it optional

    // Closures for conditionally adding dividers. They now accept the base class.
    let dividerBefore: ((CanvasTool) -> Bool)?
    let dividerAfter: ((CanvasTool) -> Bool)?

    // MARK: - Init
    
    init(
        tools: [CanvasTool],
        selectedTool: Binding<CanvasTool?>, // The binding is now to an optional base class
        dividerBefore: ((CanvasTool) -> Bool)? = nil,
        dividerAfter: ((CanvasTool) -> Bool)? = nil
    ) {
        self.tools = tools
        self._selectedTool = selectedTool
        self.dividerBefore = dividerBefore
        self.dividerAfter = dividerAfter
    }

    // MARK: - Body

    var body: some View {
        ViewThatFits {
            toolbarContent
            ScrollView(.vertical) { // Ensure vertical scrolling if it overflows
                toolbarContent
            }
            .scrollIndicators(.never)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
        .buttonStyle(.borderless)
    }

    private var toolbarContent: some View {
        VStack(spacing: 8) {
            ForEach(tools, id: \.self) { tool in
                if let dividerBefore, dividerBefore(tool) {
                    Divider().frame(width: 22)
                }
                toolbarButton(for: tool)
                if let dividerAfter, dividerAfter(tool) {
                    Divider().frame(width: 22)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 38)
    }

    // MARK: - Subviews

    private func toolbarButton(for tool: CanvasTool) -> some View {
        let index = tools.firstIndex(of: tool) ?? 0
        // Safely check if the current tool is the selected one.
        let isSelected = (tool.id == selectedTool?.id)

        return Button {
            selectedTool = tool
        } label: {
            Group {
                // --- THIS IS THE FIX (1/2) ---
                // We use a type-safe `is` check to handle special cases.
                // This assumes `ConnectionTool` is a class inheriting from `CanvasTool`.
//                if tool is ConnectionTool {
//                    // Use the tool's own `symbolName` property directly.
//                    Image(tool.symbolName)
//                } else {
                    // --- THIS IS THE FIX (2/2) ---
                    // For all other tools, directly use their `symbolName` property.
                    Image(systemName: tool.symbolName)
//                }
            }
            .font(.system(size: 16))
            .frame(width: 22, height: 22)
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .if(index < 9) { view in
            view.keyboardShortcut(
                KeyEquivalent(Character(String(index + 1))),
                modifiers: []
            )
        }
        // The tool's `label` property is used directly.
        .help("\(tool.label) Tool\nShortcut: \(index + 1)")
    }
}
