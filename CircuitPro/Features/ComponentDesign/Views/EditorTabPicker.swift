//
//  EditorTabPicker.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case elements  = "Elements"
    case geometry  = "Geometry"
    var id: Self { self }
}

struct EditorTabPicker: View {
    @Binding var selection: EditorTab
    var body: some View {
        Picker("Editor Tab Picker", selection: $selection) {
            ForEach(EditorTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
