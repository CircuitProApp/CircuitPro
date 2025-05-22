//
//  SectionView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 5/6/25.
//

import SwiftUI

struct SectionView<Content: View>: View {
    let title: String?
    let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let title = title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    .padding(5)
            }

            content()
        }
    }
}
