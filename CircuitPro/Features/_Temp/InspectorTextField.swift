//
//  InspectorTextField.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/24/25.
//

import SwiftUI

struct InspectorTextField: View {

    var label: String?
    @Binding var text: String
    
    var placeholder: String = ""
    
    var alignment: VerticalAlignment = .lastTextBaseline
    
    var body: some View {
        HStack(spacing: 5) { // This HStack defaults to .center alignment
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField(placeholder, text: $text)
        }
        .inspectorField()
    }
}
