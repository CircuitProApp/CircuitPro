//
//  UtilityAreaView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI

struct UtilityAreaView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Utility Area")
                .frame(width: 40)
            Divider()
                .foregroundStyle(.quaternary)
            Text("Secondary Panel ")
                .frame(width: 240)
            Divider()
                .foregroundStyle(.quaternary)
            Text("Content Area")
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UtilityAreaView()
}
