//
//  SidebarContentUnavailableView.swift
//  CircuitPro
//

import SwiftUI

struct SidebarContentUnavailableView: View {
    let title: String
    let systemImage: String?
    let description: String?

    init(
        _ title: String,
        systemImage: String? = nil,
        description: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let description {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
