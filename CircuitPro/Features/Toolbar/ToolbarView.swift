//
//  requiring.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI

/// A generic toolbar driven by any CanvasTool.
struct ToolbarView<Tool: CanvasTool>: View {
    let tools: [Tool]
    let dividerBefore: ((Tool) -> Bool)?
    let dividerAfter: ((Tool) -> Bool)?
    let imageName: (Tool) -> String
    let onToolSelected: (Tool) -> Void

    @State private var selectedTool: Tool
    @State private var hoveredTool: Tool?

    init(
        tools: [Tool],
        dividerBefore: ((Tool) -> Bool)? = nil,
        dividerAfter: ((Tool) -> Bool)? = nil,
        imageName: @escaping (Tool) -> String,
        onToolSelected: @escaping (Tool) -> Void
    ) {
        self.tools = tools
        self.dividerBefore = dividerBefore
        self.dividerAfter = dividerAfter
        self.imageName = imageName
        self.onToolSelected = onToolSelected
        _selectedTool = State(initialValue: tools.first!)
    }

    var body: some View {
        ViewThatFits {
            toolbarContent
            ScrollView {
                toolbarContent
            }
            .scrollIndicators(.never)
        }
        .background(.thinMaterial)
        .clipAndStroke(with: .rect(cornerRadius: 10), strokeColor: .gray.opacity(0.3), lineWidth: 1)
        .buttonStyle(.borderless)
    }

    private var toolbarContent: some View {
        VStack(spacing: 8) {
            ForEach(tools, id: \.self) { tool in
                if let dividerBefore = dividerBefore, dividerBefore(tool) {
                    Divider().frame(width: 22)
                }
                toolbarButton(tool)
                if let dividerAfter = dividerAfter, dividerAfter(tool) {
                    Divider().frame(width: 22)
                }
            }
        }
        .padding(8)
        .frame(width: 38)
    }

    private func toolbarButton(_ tool: Tool) -> some View {
        Button {
            selectedTool = tool
            onToolSelected(tool)
        } label: {
            Image(systemName: imageName(tool))
                .font(.system(size: 16))
                .frame(width: 22, height: 22)
                .foregroundStyle(selectedTool == tool ? .blue : .secondary)
        }
        // TODO: Add shortcuts
        .help("\(tool.label) Tool\nShortcut:")
    }
}
