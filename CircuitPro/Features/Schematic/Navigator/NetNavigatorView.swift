// Features/Workspace/Navigator/NetNavigatorView.swift (Corrected)

import SwiftUI

struct NetNavigatorView: View {

    @BindableEnvironment(\.editorSession)
    private var editorSession

    var body: some View {
        let nets = buildNets()

        if nets.isEmpty {
            VStack {
                Text("No Nets")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(nets, id: \.id, selection: $editorSession.selectedNetIDs) { net in
                Text(net.name)
                    .frame(height: 14)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 14)
        }
    }

    private func buildNets() -> [NetSummary] {
        let items = editorSession.schematicController.items
        let points = items.compactMap { $0 as? any ConnectionPoint }
        let links = items.compactMap { $0 as? any ConnectionLink }

        guard !links.isEmpty else { return [] }

        var adjacency: [UUID: Set<UUID>] = [:]
        adjacency.reserveCapacity(links.count * 2)
        for link in links {
            adjacency[link.startID, default: []].insert(link.endID)
            adjacency[link.endID, default: []].insert(link.startID)
        }

        var visited = Set<UUID>()
        var components: [[UUID]] = []
        components.reserveCapacity(adjacency.count)

        for startID in adjacency.keys {
            if visited.contains(startID) {
                continue
            }
            var stack = [startID]
            visited.insert(startID)
            var group: [UUID] = []

            while let current = stack.popLast() {
                group.append(current)
                for neighbor in adjacency[current, default: []] {
                    if visited.insert(neighbor).inserted {
                        stack.append(neighbor)
                    }
                }
            }

            if !group.isEmpty {
                components.append(group)
            }
        }

        let pinPointsByID = Dictionary(
            uniqueKeysWithValues: points.compactMap { $0 as? SymbolPinPoint }
                .map { ($0.id, $0) }
        )
        let componentsBySymbolID = Dictionary(
            uniqueKeysWithValues: items.compactMap { $0 as? ComponentInstance }
                .map { ($0.symbolInstance.id, $0) }
        )

        let unsortedNets = components.map { ids -> NetSummary in
            let nameSeed = ids.map { $0.uuidString }.sorted().joined(separator: "|")
            let id = UUID(name: nameSeed, namespace: NetSummary.namespace)
            let pinNames = Set(ids.compactMap { id -> String? in
                guard let pinPoint = pinPointsByID[id],
                      let component = componentsBySymbolID[pinPoint.symbolID],
                      let pin = component.symbolInstance.definition?.pins.first(where: { $0.id == pinPoint.pinID })
                else { return nil }
                let trimmed = pin.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            })
            return NetSummary(id: id, pinNames: pinNames)
        }

        let sorted = unsortedNets.sorted { $0.id.uuidString < $1.id.uuidString }
        return sorted.enumerated().map { index, net in
            let name: String
            if net.pinNames.count == 1, let only = net.pinNames.first {
                name = only
            } else {
                name = "Net \(index + 1)"
            }
            return NetSummary(id: net.id, name: name, pinNames: net.pinNames)
        }
    }
}

private struct NetSummary: Identifiable {
    let id: UUID
    let name: String
    let pinNames: Set<String>

    init(id: UUID, name: String = "", pinNames: Set<String>) {
        self.id = id
        self.name = name
        self.pinNames = pinNames
    }

    static let namespace = UUID(uuidString: "5D79F07B-70B2-4B5D-9EBB-1A8C4D6631F9")!
}
