//
//  InspectorAnchorRow.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/28/25.
//

import SwiftUI

struct InspectorAnchorRow: View {
    
    @Binding var textAnchor: TextAnchor
    
    var body: some View {
        InspectorRow("Anchor") {
            AnchorPickerView(selectedAnchor: $textAnchor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(textAnchor.label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
