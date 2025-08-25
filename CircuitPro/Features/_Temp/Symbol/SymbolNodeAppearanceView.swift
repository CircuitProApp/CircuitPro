//
//  SymbolNodeAppearanceView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/25/25.
//

import SwiftUI
import SwiftDataPacks

struct SymbolNodeAppearanceView: View {
    @Environment(\.projectManager) private var projectManager
    @PackManager private var packManager
    
    let component: DesignComponent
    @Bindable var symbolNode: SymbolNode
    
    @State private var selection: Int?
    
    var body: some View {
        VStack(spacing: 15) {
            InspectorSection("Text Visibility") {
                PlainList(selection: $selection) {
                    
                    ForEach(1...2, id: \.description) { int in
                        Text(int.description)
                            .listID(int)
                    }
                    Divider()
                    ForEach(0...10, id: \.description) { int in
                        Text(int.description)
                            .listID(int)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipAndStroke(with: .rect(cornerRadius: 5))
                .listConfiguration { configuraion in
                    configuraion.listRowPadding = .horizontal(5, vertical: 2.5)
                    configuraion.selectionForegroundColor = .white
                }
             
                .padding(.horizontal, 5)
            }
        }
    }
}
