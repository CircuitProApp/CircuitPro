//
//  ComponentDrawerView.swift
//  Circuit Pro
//
//  Created by Giorgi Tchelidze on 4/5/25.
//

import SwiftUI
import RealityKit
import SwiftData

struct ComponentDrawerView: View {

    enum LibraryType: String, CaseIterable {
        case design = "Design Library"
        case app = "App Library"
        case user = "User Library"
    }

    @Environment(\.appManager)
    private var appManager
    @Environment(\.projectManager)
    private var projectManager
    @Environment(\.modelContext)
    private var modelContext

    @Query private var components: [Component]
//    @Query private var componentInstances: [ComponentInstance]

    @State private var selectedLibraryType: LibraryType = .design

    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            librarySelector
            switch selectedLibraryType {
            case .design:
//                ComponentGridView(projectManager.activeComponentInstances) { instance in
//                    VStack {
//                        Text(components.first(where: { $0.uuid == instance.componentUUID })?.name ?? "")
//                    }
//                    .padding(10)
//                    .frame(width: 150, height: 50, alignment: .leading)
//                    .background(.gray.opacity(0.1))
//                    .clipAndStroke(with: .rect(cornerRadius: 15))
//                }
                Text("Pending")
            case .app:
                ComponentGridView(components) { component in
                    ComponentCardView(component: component)
                }
            default:
                Text("Library")
            }
        }
        .padding(10)
        .frame(height: 250)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .clipAndStroke(with: .rect(cornerRadius: 10), strokeColor: .gray.opacity(0.3), lineWidth: 1)
        .transition(.move(edge: .bottom).combined(with: .blurReplace))
        .onAppear {
//            if componentInstances.isEmpty {
//                selectedLibraryType = .app
//            }
        }
    }

    var librarySearchField: some View {
        HStack {
            TextField("Search Components", text: $searchText)
                .textFieldStyle(.plain)
                .directionalPadding(vertical: 7.5, horizontal: 10)
                .background(.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    var librarySelector: some View {
        HStack {
            ForEach(LibraryType.allCases.dropLast(), id: \.self) { libraryType in
                Button {
                    withAnimation {
                        selectedLibraryType = libraryType
                    }
                } label: {
                    Text(libraryType.rawValue)
                }
                .buttonStyle(.plain)
                .directionalPadding(vertical: 5, horizontal: 7.5)
                .background(selectedLibraryType == libraryType ? .gray.opacity(0.2) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                if libraryType == .design {
                    Divider()
                        .frame(height: 15)
                }

            }
            Spacer()
//            Button {
//                appManager.path.append(CircuitProPage.componentDesign)
//            } label: {
//                Text("Create a Component")
//            }

        }
        .font(.subheadline)
    }
}
// swiftlint:disable:next line_length
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
                    columns: Array(repeating: GridItem(.adaptive(minimum: 150, maximum: 200)), count: 3),
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

#Preview {
    ComponentDrawerView()
}
