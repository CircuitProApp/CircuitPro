import SwiftUI

/// A generic toolbar driven by a tool list builder.
struct CanvasToolbarView: View {

    // MARK: - Properties

    private struct Entry {
        let item: CanvasToolbarItem
        let toolIndex: Int?
    }

    private let entries: [Entry]
    @Binding var selectedTool: CanvasTool? // Use the base class and make it optional

    // MARK: - Init

    init(
        selectedTool: Binding<CanvasTool?>,
        @CanvasToolbarBuilder tools: () -> [CanvasToolbarItem]
    ) {
        self._selectedTool = selectedTool
        self.entries = CanvasToolbarView.makeEntries(from: tools())
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
        .buttonStyle(.plain)
        .glassEffect(in: .capsule)

    }

    private var toolbarContent: some View {
        VStack(spacing: 8) {
            ForEach(entries.indices, id: \.self) { index in
                toolbarEntry(entries[index])
            }
        }
        .padding(8)
        .frame(minWidth: 38)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func toolbarEntry(_ entry: Entry) -> some View {
        switch entry.item {
        case .divider:
            Divider().frame(width: 22)
        case .tool(let tool):
            toolbarButton(for: tool, toolIndex: entry.toolIndex ?? 0)
        }
    }

    private func toolbarButton(for tool: CanvasTool, toolIndex: Int) -> some View {
        // Safely check if the current tool is the selected one.
        let isSelected = (tool.id == selectedTool?.id)

        return Button {
            selectedTool = tool
        } label: {
            Group {
                if tool is WireTool {
                    Image(tool.symbolName)
                } else {
                    Image(systemName: tool.symbolName)
                }
            }
            .font(.system(size: 16))
            .frame(width: 22, height: 22)
            .contentShape(.rect)
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        .if(toolIndex < 9) { view in
            view.keyboardShortcut(
                KeyEquivalent(Character(String(toolIndex + 1))),
                modifiers: []
            )
        }
        // The tool's `label` property is used directly.
        .help("\(tool.label) Tool\nShortcut: \(toolIndex + 1)")
    }

    private static func makeEntries(from items: [CanvasToolbarItem]) -> [Entry] {
        var nextIndex = 0
        return items.map { item in
            switch item {
            case .tool:
                defer { nextIndex += 1 }
                return Entry(item: item, toolIndex: nextIndex)
            case .divider:
                return Entry(item: item, toolIndex: nil)
            }
        }
    }
}
