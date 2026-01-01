//
//  UtilityAreaView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI
import SwiftData

enum UtilityAreaTab: Displayable {

    case canvasConsole

    var label: String {
        switch self {
        case .canvasConsole:
            return "Canvas Console"

        }
    }

    var icon: String {
        switch self {
        case .canvasConsole:
            return "apple.terminal"
        }
    }
}

struct UtilityAreaView: View {

    @State private var selectedTab: UtilityAreaTab = .canvasConsole

    var body: some View {
        HStack(spacing: 0) {
            utilityAreaTab

            Divider()
                .foregroundStyle(.quaternary)

            selectionView
            .frame(width: 240)

            Divider()
                .foregroundStyle(.quaternary)
            contentView
            .frame(maxWidth: .infinity)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionView: some View {
        Group {
            Text("WIP")
        }
    }

    private var utilityAreaTab: some View {
        VStack(spacing: 12.5) {
            ForEach(UtilityAreaTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: tab == selectedTab ? "\(tab.icon).fill" : tab.icon)
                        .font(.system(size: 12.5))
                        .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                        .if(tab == .canvasConsole) { view in
                            view.padding(.top, 12.5)
                        }
                }
                .buttonStyle(.plain)
                .help(tab.label)

            }
            Spacer()
        }
        .frame(width: 40)
    }

    private var contentView: some View {
        Group {

                Text("WIP")

        }
    }
}
