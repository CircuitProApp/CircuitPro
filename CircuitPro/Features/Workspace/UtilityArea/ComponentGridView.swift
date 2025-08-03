//
//  ComponentGridView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/3/25.
//

import SwiftUI
import SwiftData

struct ComponentGridView<Data: RandomAccessCollection, Content: View>: View where Data.Element: PersistentModel {

    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        if data.isEmpty {
            Text("No Components")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
        } else {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.adaptive(minimum: 200, maximum: 200)), count: 3),
                    alignment: .leading
                ) {
                    ForEach(data, id: \.persistentModelID) { element in
                        content(element)
                    }
                }
                .disableAnimations()
            }
        }
    }
}
