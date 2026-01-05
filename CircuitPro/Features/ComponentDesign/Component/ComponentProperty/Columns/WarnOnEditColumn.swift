//
//  WarnOnEditColumn.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/21/25.
//
import SwiftUI

struct WarnOnEditColumn: View {
    @Binding var property: DraftProperty

    var body: some View {
        Toggle("Warn on Edit", isOn: $property.warnsOnEdit)
            .labelsHidden()
    }
}
