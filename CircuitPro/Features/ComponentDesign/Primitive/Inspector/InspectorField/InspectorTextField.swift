//
//  InspectorTextField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/30/25.
//

import SwiftUI

struct InspectorTextField: View {

    let title: String
    @Binding var text: String
    
    var placeholder: String = ""
    
    var titleDisplayMode: TitleDisplayMode = .label
    
    enum TitleDisplayMode {
        case label
        case hidden
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if titleDisplayMode == .label {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            TextField(placeholder, text: $text)
                .inspectorField()
        }
    }
}
