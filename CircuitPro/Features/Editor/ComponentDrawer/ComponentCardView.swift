//
//  ComponentCardView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/7/25.
//

import SwiftUI
import RealityKit

struct ComponentCardView: View {

    let component: Component

    @State private var selectedViewType: ComponentViewType = .symbol

    var body: some View {
        HStack {
            VStack {
                VStack {
                    Text(component.name)
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    selectedView
                    Spacer()
                }
                Spacer()
                componentViewTypeSwitcher
            }
            .padding(5)
            .frame(width: 150, height: 150)
            .background(.gray.opacity(0.1))
            .clipAndStroke(with: .rect(cornerRadius: 15))
            .draggableIfPresent(TransferableComponent(component: component))
        }
    }

    var selectedView: some View {
        Group {
            switch selectedViewType {
            case .symbol:
                VStack {
                    Text(component.symbol?.primitives.count.description ?? "No primitives")
                    Text(component.symbol?.pins.count.description ?? "No primitives")
                }
            case .footprint:
                if component.footprints.isNotEmpty {
                    Image(AppIcons.photoTriangleBadgeExclamationMark)
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.quaternary)
                } else {
                    Text("Footprint View")
                }
            }
        }
    }

    var componentViewTypeSwitcher: some View {
        HStack {
            ForEach(ComponentViewType.allCases, id: \.self) { type in
                Button {
                    selectedViewType = type
                } label: {
                    Label(type.label, systemImage: type.icon)
                        .foregroundStyle(selectedViewType == type ? .blue : .primary)
                }
                .disabled(!type.isAvailable(in: component))

                if type != ComponentViewType.allCases.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    func realityView(_ name: String) -> some View {
        RealityView { content in
            if let model = try? await ModelEntity(named: name) {
                content.add(model)
                model.scale = .init(x: 30, y: 30, z: 30)
            }
        } placeholder: {
            ProgressView()
        }
    }
}

#Preview {
    ComponentCardView(component: Component(name: "Pololu Distance Sensor"))
}
